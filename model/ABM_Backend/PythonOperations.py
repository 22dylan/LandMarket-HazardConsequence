import os
import shutil
import numpy as np
import pandas as pd
import geopandas as gpd
from pyincore import IncoreClient, Dataset, FragilityService, DataService, MappingSet
from pyincore.analyses.housingunitallocation import HousingUnitAllocation
from pyincore.analyses.buildingdamage import BuildingDamage
from pyincore.analyses.cumulativebuildingdamage import CumulativeBuildingDamage

""" 
	NOTE: To get geopandas to work in julia with pyCall, I had to install fiona
		into julia's conda distribution using:
			Conda.pip("install", "fiona")
		The remaining packages (e.g., incore) was installed using:
			Conda.add("pyincore", channel="in-core")
"""


class misc_python_ops():
	def __init__(self):
		self.client = IncoreClient()

		self.temp_dir = os.path.join(os.getcwd(), 'temp')
		self.makedir(self.temp_dir)

	def complete_run(self):
		self.removedir(self.temp_dir)


	def prepare_parcel_df(self, input_folder, seed=1337):
		""" prepares input files to be digested into Julia and eventually ABM. 
			There's probably a way to read spatial data into Julia and convert 
				it to the correct CRS, but I couldn't figure this out.
			Instead, I'm using geopandas to perform this operation
		"""
		inputfile_dict = self.read_input_folder(input_folder, file_tf=True, dirs_tf=True)

		prcl_df = inputfile_dict['Buildings']
		prcl_df.set_index('guid', inplace=True)

		prcl_df = self.distance_calcs(input_dict=inputfile_dict, prcl_df=prcl_df, feature='CommunityAssets', col_name='d_commasst')
		prcl_df = self.distance_calcs(input_dict=inputfile_dict, prcl_df=prcl_df, feature='Beach', col_name='d_coast')
		prcl_df = self.distance_calcs(input_dict=inputfile_dict, prcl_df=prcl_df, feature='GreenSpace', col_name='d_grnspc')
		prcl_df['d_commasst'] = prcl_df[['d_commasst','d_grnspc']].min(axis=1)

		prcl_df["year_built"] 

		zones = inputfile_dict['Zoning'].copy()

		prcl_df['zone'] = 0
		prcl_df['zone_type'] = 0
		for i, row in zones.iterrows():
			bldg_in_zone = prcl_df.within(row['geometry'])
			prcl_df.loc[bldg_in_zone==True, 'zone'] = row['guid']
			prcl_df.loc[bldg_in_zone==True, 'zone_type'] = row['zone_abbr']

		# assuming parcels outside of Seaside's original zoning layer are zoned as open space
		prcl_df.loc[prcl_df['zone_type']==0, 'zone'] = 'outside_SeasideZones'
		prcl_df.loc[prcl_df['zone_type']==0, 'zone_type'] = 'OS'


		# --- initializing population for iteration
		# todo: read hua building inventory from pyincore, not locally
		
		hua_path_out = os.path.join(self.temp_dir, 'temp_hua')
		hua_df = self.housing_unit_allocation(seed=seed, result_name=hua_path_out)
		prcl_df = pd.merge(prcl_df, hua_df, how='left', left_index=True, right_index=True)
		prcl_df = self.assign_property_types(prcl_df, comm_bldgs=inputfile_dict['DataAxelCommericalBuildingMapping_drs'])

		# normalizing the location of all parcels
		# prcl_df, space_conv = self.normalize_loc(prcl_df)
		prcl_df['x'] = prcl_df.geometry.x
		prcl_df['y'] = prcl_df.geometry.y

		prcl_df.reset_index(inplace=True)
		cols = ['guid', 'struct_typ', 'year_built', 'no_stories', 'dgn_lvl',
				'd_commasst', 'd_coast', 'zone', 'zone_type', 
				'numprec', 'landuse', 'owner_type', 'max_n_agents', 'x', 'y']
		prcl_df = prcl_df[cols]
		return prcl_df


	def read_input_folder(self, path, file_tf=True, dirs_tf=True):
		""" recursively read all files in input folder.
		"""
		all_in_dir = os.listdir(path)
		input_dict = {}
		if file_tf:
			files = [f for f in all_in_dir if os.path.isfile(os.path.join(path, f))]
			for f in files:
				key = f.split('.')[0]
				input_dict[key] = pd.read_csv(os.path.join(path, f))
		if dirs_tf:
			dirs = [d for d in all_in_dir if os.path.isdir(os.path.join(path, d))]
			for d in dirs:
				input_dict[d] = self.df_from_subdirectory(path, d)
		return input_dict


	def df_from_subdirectory(self, input_dir, folder):
		path_to_shp = os.path.join(input_dir, folder)
		files = os.listdir(path_to_shp)
		file = [i for i in files if '.shp' in i][0]
		path_to_shp = os.path.join(path_to_shp, file)
		gdf = gpd.read_file(path_to_shp)
		gdf = gdf.to_crs(26910)		# converting such that crs units is in meters, not lat/long
		return gdf


	def distance_calcs(self, input_dict=None, prcl_df=None, feature=None, col_name=None):
		feature_df = input_dict[feature].copy()
		if len(feature_df) == 0:
			min_dist = np.ones(len(prcl_df))*np.inf
		else:
			min_dist = np.zeros(len(prcl_df))
			for i, point in enumerate(prcl_df.geometry):
				min_dist[i] = np.min([point.distance(line) for line in feature_df.geometry])
		prcl_df[col_name] = min_dist
		return prcl_df


	# def normalize_loc(self, prcl_df):
	# 	""" Prepares an x and y location for each parcel.
	# 		In Agents.jl, the continous space is setup such that the lowerleft 
	# 		  corner is at (0,0). 
	# 		Here, each parcel is normalized to this lower left corner
	# 	"""
	# 	minx, miny, maxx, maxy = prcl_df.geometry.total_bounds 	# getting bounds of geometry	
	# 	minx -= 1
	# 	miny -= 1
	# 	x = []
	# 	y = []

	# 	for i, row in prcl_df.iterrows():
	# 		geom = row['geometry']
	# 		x.append(geom.x - minx)
	# 		y.append(geom.y - miny)

	# 	prcl_df['x'] = x
	# 	prcl_df['y'] = y		
	# 	return prcl_df, (minx, miny)


	def housing_unit_allocation(self, result_name=None, seed=None):
		""" housing unit allocation
			numprec: number of persons in structure
			ownership: tenure status
				1 - Owned or being bought (load)
				2 - rented
				3 - seasonal rental
			race: race
				1 - white alone
				2 - black alone
				3 - american indian/alaska native alone
				4 - asian alone
				5 - native hawaiin/other pacific islander alone
				6 - some other race
				7 - two or more races
			hispan: Hispanic
				0 - not hispanic
				1 - hispanic/latino
			vacancy: Vacancy type
				0 - n/a
				1 - for rent
				2 - rented, not occupied
				3 - for sale only
				4 - sold, not occupied
				5 - for seasonal, recreational, or occasional use
				6 - for migrant workers
				7 - other vacant
			gqtype: group quarters type
				0 - NA (non-group quarters households)
				1 - correctional facilities for adults
				2 - juvenile facilities
				3 - nursing facilities
				6 - college/university student housing
				7 - military quarters
				8 - other noninstitutional facilities
			livetype: Live type unit
				H - residential housing unit
				G - group quarters
			
		"""
		# Create housing allocation 
		hua = HousingUnitAllocation(self.client)

		# Load input dataset
		housing_unit_inv_id = "5d543087b9219c0689b98234"
		address_point_inv_id = "5d542fefb9219c0689b981fb"
		bldg_inv_id = "613ba5ef5d3b1d6461e8c415"

		hua.load_remote_input_dataset("housing_unit_inventory", housing_unit_inv_id)
		hua.load_remote_input_dataset("address_point_inventory", address_point_inv_id)
		hua.load_remote_input_dataset("buildings", bldg_inv_id)


		# Set analysis parameters
		hua.set_parameter("result_name", result_name)
		hua.set_parameter("seed", seed)
		hua.set_parameter("iterations", 1)
		hua.run_analysis()

		# Retrieve result dataset
		hua_result = hua.get_output_dataset("result")

		# Convert dataset to Pandas DataFrame
		hua_df = hua_result.get_dataframe_from_csv(low_memory=False)
		hua_df = hua_df[['guid', 'numprec', 'ownershp', 'race', 'hispan', 'vacancy', 'gqtype', 'livetype']]

		# keep observations where the housing unit characteristics have been allocated to a structure.
		hua_df = hua_df.dropna(subset=['guid'])

		# grouping dataframe by guid; taking sum of numprec, mode of others
		numprec = hua_df[['guid', 'numprec']].groupby(['guid']).sum()
		other = hua_df[['guid', 'ownershp', 'race', 'hispan', 'vacancy', 'gqtype', 'livetype']].groupby(['guid']).apply(lambda x: x.mode().iloc[0])
		del other['guid']	# somehow duplicated in "other"

		hua_df = pd.merge(numprec, other, left_index=True, right_index=True)
		return hua_df


	def assign_property_types(self, hua_df, comm_bldgs=None):
		""" 
		assigning initial land use types based on housing unit allocation (hua)
		
		Land use types:
			- unoccupied 						(unoccupied)
			- owned residential 				(owned_res)
			- rental residential 				(rentl_res)
			- low occupancy seasonal rental 	(losr)
			- high occupancy residential 		(hor)
			- commercial 						(commercial)
			- high occupancy seasonal rental 	(hosr)
		
		Keys from HUA used:
			- vacancy: vacancy type
				+ 0: n/a
				+ 1: for rent
				+ 2: rented; not occupied
				+ 3: for sale
				+ 4: sold, not occupied
				+ 5: for seaona rental
				+ 6: For migrant workers
				+ 7: other vacant
			- ownershp: tenure status
				+ 1: Owned or being bought
				+ 2: rented
				+ 3: seasonal rental
		"""
		landuse = []		# parcel land use
		numprec = []		# number of people
		agnt_typ = []
		max_n_agents = []

		for index, row in hua_df.iterrows():
			if index in comm_bldgs['guid'].values:
				landuse.append('commercial')
				numprec.append(0)
				agnt_typ.append('developer')
				max_n_agents.append(0)
				continue

			if (row.vacancy==0) & (row.ownershp==1): # ownershp=1: owned
				landuse.append('owned_res')
				numprec.append(row.numprec)
				agnt_typ.append('individual')
				max_n_agents.append(1)


			elif (row.vacancy==0) & (row.ownershp==2): # ownershp=2: rented
				if row.no_stories <= 2:
					landuse.append('rentl_res')
					agnt_typ.append('landlord')
					max_n_agents.append(2)

				else:
					landuse.append('hor')
					agnt_typ.append('developer')
					max_n_agents.append(10)

				numprec.append(row.numprec)

			elif (row.vacancy==0) & (row.ownershp==3): # ownershp=3: seasonal rental
				if row.no_stories <= 2:
					landuse.append('losr')
					agnt_typ.append('landlord')
					max_n_agents.append(1)


				else:
					landuse.append('hosr')
					agnt_typ.append('developer')
					max_n_agents.append(1)

				numprec.append(row.numprec)

			elif (row.vacancy==0):	# these are group quarters; assuming high occupancy res
				landuse.append('hor')
				numprec.append(row.numprec)
				agnt_typ.append('developer')
				max_n_agents.append(10)


			# --- following are vacant; ensure nobody is in property
			elif (row.vacancy==1): # for rent
				landuse.append('unoccupied')
				numprec.append(0)
				agnt_typ.append('unocc_owner')
				max_n_agents.append(0)



			elif (row.vacancy==2): # rented, unoccupied
				if row.no_stories <= 2:
					landuse.append('rentl_res')
					agnt_typ.append('landlord')
					max_n_agents.append(2)

				else:
					landuse.append('hor')
					agnt_typ.append('developer')
					max_n_agents.append(10)


				numprec.append(0)

			elif (row.vacancy==3): # for sale
				landuse.append('unoccupied')
				numprec.append(0)
				agnt_typ.append('unocc_owner')
				max_n_agents.append(0)


			elif (row.vacancy == 4):	# sold, unoccupied
				landuse.append('owned_res')
				numprec.append(0)
				agnt_typ.append('individual')
				max_n_agents.append(1)


			elif (row.vacancy==5):	# seasonal/recreational use
				if row.no_stories <= 2:
					landuse.append('losr')
					agnt_typ.append('landlord')
					max_n_agents.append(2)

				else:
					agnt_typ.append('developer')
					landuse.append('hosr')
					max_n_agents.append(1)


				numprec.append(0)

			elif (row.vacancy==6):	# migrant workers; assuming seaonal rental
				if row.no_stories <= 2:
					landuse.append('losr')
					agnt_typ.append('landlord')
					max_n_agents.append(1)

				else:
					agnt_typ.append('developer')
					landuse.append('hosr')
					max_n_agents.append(1)

				numprec.append(0)

			elif (row.vacancy==7):	# other vacant
				landuse.append('unoccupied')
				numprec.append(0)
				agnt_typ.append("unocc_owner")
				max_n_agents.append(0)



			# --- if vacancy is nan; assuming non-residential
			elif row.vacancy != row.vacancy:	# check (pythonically) if vacancy is nan				
				if row.no_stories > 2:
					landuse.append("hor")
					numprec.append(0)
					agnt_typ.append("developer")
					max_n_agents.append(10)

				else:
					landuse.append("owned_res")
					numprec.append(0)
					agnt_typ.append("individual")
					max_n_agents.append(1)

			else:
				landuse.append('unoccupied')
				numprec.append(0)
				agnt_typ.append("unocc_owner")
				max_n_agents.append(0)



		hua_df['landuse'] = landuse
		hua_df['numprec'] = numprec
		hua_df['owner_type'] = agnt_typ
		hua_df['max_n_agents'] = max_n_agents
		print(hua_df['landuse'].value_counts())

		return hua_df

	def makedir(self, path):
		""" checking if path exists and making it if it doesn't. 
			if the path doesn't exist, make dir and return False (e.g. didn't exist 
				before)
			if the path does exist, return True
		"""
		if not os.path.exists(path):
			os.makedirs(path)
			return False
		else:
			return True

	def removedir(self, path):
		shutil.rmtree(path)
		return True


	def pyincore_CSZ(self, guids, strct_typ, year_built, no_stories, x, y, rt):
		# setting up dataframe from output of Julia
		prcl_df = pd.DataFrame({"guid": guids,
								"struct_typ": strct_typ,
								"year_built": year_built,
								"no_stories": no_stories,
								"x": x,
								"y": y
								})

		# setting up geodataframe from above
		prcl_df = gpd.GeoDataFrame(prcl_df, geometry=gpd.points_from_xy(prcl_df.x, prcl_df.y))
		prcl_df = prcl_df[['guid', 'struct_typ', 'year_built', 'no_stories', 'geometry']]
		prcl_df = prcl_df.set_crs(26910)
		prcl_df = prcl_df.to_crs(4326)

		file_path = os.path.join(self.temp_dir, 'TEMP_bldgs.shp')
		prcl_df.to_file(file_path)     # writing to file
		bldg_ds = Dataset.from_file(file_path, data_type="ergo:buildingInventoryVer5")

		earthquake_hazard_id = self.earthquake_hazard_dict(rt)
		tsunami_hazard_id = self.tsunami_hazard_dict(rt)
		path_to_eq_out = os.path.join(self.temp_dir, 'eq_out.csv')
		path_to_ts_out = os.path.join(self.temp_dir, 'ts_out.csv')
		path_to_cm_out = os.path.join(self.temp_dir, 'cm_out.csv')

		self.bldg_dmg_eq(bldg_ds, earthquake_hazard_id, path_to_eq_out)
		self.bldg_dmg_tsu(bldg_ds, tsunami_hazard_id, path_to_ts_out)
		self.bldg_dmg_cmltv(path_to_eq_out, path_to_ts_out, path_to_cm_out)


	def bldg_dmg_eq(self, bldg_ds=None, hazard_id=None, result_name=None):
		""" earthquake damage """

		bldg_dmg = BuildingDamage(self.client)
		data_service = DataService(self.client)
		fragility_service = FragilityService(self.client)

		bldg_dmg.set_input_dataset("buildings", bldg_ds)

		# specifiying mapping id from fragilites to building types
		mapping_id = "5d2789dbb9219c3c553c7977"
		mapping_set = MappingSet(fragility_service.get_mapping(mapping_id))
		bldg_dmg.set_input_dataset('dfr3_mapping_set', mapping_set)

		bldg_dmg.set_parameter("hazard_type", "earthquake")
		bldg_dmg.set_parameter("num_cpu", 4)

		bldg_dmg.set_parameter("hazard_id", hazard_id)
		bldg_dmg.set_parameter("result_name", result_name)

		bldg_dmg.run_analysis()


	def bldg_dmg_tsu(self, bldg_ds=None, hazard_id=None, result_name=None):
		""" tsunami damage """
		bldg_dmg = BuildingDamage(self.client)
		data_service = DataService(self.client)
		fragility_service = FragilityService(self.client)

		bldg_dmg.set_input_dataset("buildings", bldg_ds)

		# specifiying mapping id from fragilites to building types
		mapping_id = "5d279bb9b9219c3c553c7fba"
		mapping_set = MappingSet(fragility_service.get_mapping(mapping_id))
		bldg_dmg.set_input_dataset('dfr3_mapping_set', mapping_set)

		bldg_dmg.set_parameter("hazard_type", "tsunami")
		bldg_dmg.set_parameter("num_cpu", 4)

		bldg_dmg.set_parameter("hazard_id", hazard_id)
		bldg_dmg.set_parameter("result_name", result_name)

		bldg_dmg.run_analysis()


	def bldg_dmg_cmltv(self, eq_dmg_results, tsu_dmg_results, result_name):
		""" cumulative damage """
		cumulative_bldg_dmg = CumulativeBuildingDamage(self.client)
		cumulative_bldg_dmg.set_parameter("num_cpu", 1)

		# loading datasets from CSV files into pyincore
		eq_damage_dataset = Dataset.from_file(eq_dmg_results, "ergo:buildingDamageVer5")
		tsu_damage_dataset = Dataset.from_file(tsu_dmg_results, "ergo:buildingDamageVer5")

		cumulative_bldg_dmg.set_input_dataset("eq_bldg_dmg", eq_damage_dataset)
		cumulative_bldg_dmg.set_input_dataset("tsunami_bldg_dmg", tsu_damage_dataset)

		# defining path to output 
		cumulative_bldg_dmg.set_parameter("result_name", result_name)

		# running analysis
		cumulative_bldg_dmg.run_analysis()



	def earthquake_hazard_dict(self, rt):
		eq_dict = {100: "5dfa4058b9219c934b64d495", 
						  250: "5dfa41aab9219c934b64d4b2",
						  500: "5dfa4300b9219c934b64d4d0",
						  1000: "5dfa3e36b9219c934b64c231",
						  2500: "5dfa4417b9219c934b64d4d3", 
						  5000: "5dfbca0cb9219c101fd8a58d",
						 10000: "5dfa51bfb9219c934b68e6c2"}
		return eq_dict[rt]

	def tsunami_hazard_dict(self, rt):
		tsu_dict = {100: "5bc9e25ef7b08533c7e610dc", 
						  250: "5df910abb9219cd00cf5f0a5",
						  500: "5df90e07b9219cd00ce971e7",
						  1000: "5df90137b9219cd00cb774ec",
						  2500: "5df90761b9219cd00ccff258",
						  5000: "5df90871b9219cd00ccff273",
						  10000: "5d27b986b9219c3c55ad37d0"}
		return tsu_dict[rt]

if __name__ == '__main__':
	mop = misc_python_ops()


