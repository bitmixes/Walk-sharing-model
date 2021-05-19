/***
* Name: parkvillewalkshare
* Author: dbhowmick
* Description: 
* Tags: 
***/

model walksharing

global {
	
	int sim_number <- 1;
	int end_cycle <- 360;
	int flag_write <- 0;
	
	// defining the pedestrian road network graph
	geometry shape <- envelope(2900);
	graph the_graph <- load_graph_from_file("graphml", "../includes/grid_3000by3000_2.graphml",nodepoints,road);
	
	// file defining the stops/destinations of the pedestrian agents
	file stops_csv <- csv_file("../includes/ptstops/ptstops_synthetic_uniform_49.csv",";",true);
	
	// pedestrian demand file, contains origins and destinations and other attributes assigned to the agents apriori
	string filename <- "population_synthetic_500_1601261881.csv";
	file population_input <- csv_file( "../includes/population/random_population_100to1000_60mins/"+filename,";", "'",true);
	
	// deducing the number of pedestrian agents in the input file
	int nbpeople_init <- matrix(population_input).rows;
	int nbpeople <- nbpeople_init;
	
	//randomly assigns walking speeds to pedestrian agents using normal distribution
	float mean_speed <- 4.25 #km/#h; //speed reference (Transport Modelling Guidelines (Volume 4) - VicRoads, page 146)
	float stdev_speed <- 1.0 #km/#h;
	
	// assigning maximum waiting times of agents as per uniform random distribution
	// assigned value lies between minimum and maximum
	int min_max_waiting_time <- 5#mn; 
	int max_max_waiting_time <- 10#mn;
	
	// defines distance between two pedestrian agents, considers distance between origins and destinations
	float distance_threshold <- 500.0;
	
	// defines distance threshold between the origin of the pedestrian agent and the destination
	float ptstop_search_distance <- 500.0;
	
	//probability of choosing a tram stop among the list of destinations
	float tram_choiceprob <- 0.8;
	
	
	float step <- 20 #second;
	int current_min update: (time / 60);	
	
	init {
		create road from: the_graph ;
		map<road, float> weights_map <- road as_map (each:: each.shape.perimeter);
		the_graph <- as_edge_graph(road) with_weights weights_map;
		create nodepoints from: nodepoints;
		
		create people from: population_input with: 
			[	
				name::string(get("name")), 
				location::point(get("loc_orig")),
				start_walk::int(get("start_walk"))	
			];
			
		create stopscsv from: stops_csv with:
			[
				type::string(get("highway")),
				type_index::int(get("stop_type_index")),
				location::point(get("loc"))			
			];
			

		write(sample(matrix(population_input).rows));
		write(sample(length(matrix(population_input))));
		write sample(stopscsv.attributes);
		write(list(stopscsv collect each.type));
		write(list(stopscsv collect each.type_index));
		write(list(stopscsv collect each.location));
	}
	
	
	reflex info_time {
		write "\n-------------------------------------------";
		write "cycle: " + cycle;
		write "time: " + time;
		write "number of agents left: " + nbpeople;	
		
		if cycle = 0 {
			write "agents left: ";
			write "All";
		}	
	}
	

	// MATCHING ALGORITHM
	reflex match when: nbpeople > 0 {
		list match_pool <- [];
		int count_match_pool ;
		ask people {
			if flag_active = 1 {
				add name to: match_pool;
			}
		}
		count_match_pool <-  length(match_pool);
		write(sample(match_pool));
		write(sample(count_match_pool));
		
		if count_match_pool > 1 {
			matrix dist_matrix <- 0.0 as_matrix({count_match_pool,count_match_pool}); 
			matrix index_matrix <- list as_matrix({count_match_pool,count_match_pool}); 
			loop i from: 0 to: count_match_pool-1 {
				list dist_list <- [];
				string ped_name <- match_pool[i];
				int ped_index <- list(people collect each.name) index_of ped_name;
				point ped_loc_orig <- people[ped_index]['location'];
				point ped_loc_dest <- people[ped_index]['pt_destination'];
				loop j from: 0 to: count_match_pool-1 {
					string ped_j_name <- match_pool[j];
					int ped_j_index <- list(people collect each.name) index_of ped_j_name;
					point ped_j_loc_orig <- people[ped_j_index]['location'];
					point ped_j_loc_dest <- people[ped_j_index]['pt_destination'];
					float dist_orig <- sqrt((float(ped_loc_orig.x) - float(ped_j_loc_orig.x))^2 + (float(ped_loc_orig.y) - float(ped_j_loc_orig.y))^2);
					float dist_dest <- sqrt((float(ped_loc_dest.x) - float(ped_j_loc_dest.x))^2 + (float(ped_loc_dest.y) - float(ped_j_loc_dest.y))^2);
					float dist <- sqrt((dist_orig)^2 + (dist_dest)^2);
					list index_list <- [ped_index, ped_j_index];
					put index_list at: {i,j} in: index_matrix;
					put dist at: {i,j} in: dist_matrix;
				}		
			}

			write(sample(dist_matrix));	
			float min_dist <- min (dist_matrix);
			point min_dist_index <- dist_matrix index_of min_dist;

			
			//replace diagonal elements and elements above the diagonal with large positive values
			loop i from: 0 to: count_match_pool-1 {
				loop j from: 0 to: count_match_pool-1 {
					if i >= j {
						dist_matrix[i,j] <- 100000.0; //replace by a very large value
					}
				}
			}
			
			write(sample(dist_matrix));
			
			//get a list of viable matches and their locations in the dist_matrix
			//use the same locations to get the indices of agents with min distance from the index_matrix
			list viable_matches_zerodistance <- dist_matrix sort_by each where (each = 0.0);
			list viable_matches <- dist_matrix sort_by each where (each < distance_threshold and each >0.0);
			write(sample(viable_matches_zerodistance));
			write(sample(length(viable_matches_zerodistance)));
			write(sample(viable_matches));
			write(sample(length(viable_matches)));
			list matched_agents_check;
			list matched_agents;
			list matched_agents_indices;
			
			loop index_row from: 0 to: dist_matrix.rows - 1 {
				loop index_column from: 0 to: dist_matrix.columns - 1 {
					if dist_matrix[index_row, index_column] =  0.0 {
						list min_dist_agent_indices_k <- index_matrix[index_row, index_column];
						bool skip <- matched_agents_check contains_any [people[min_dist_agent_indices_k[0]]['name'],people[min_dist_agent_indices_k[1]]['name']];
						if skip = false { //check for agents already matched
							write "New agents zero distance: ";
							list buddies;
							list buddy_indices;
							people[min_dist_agent_indices_k[0]]['assigned_buddy'] <- people[min_dist_agent_indices_k[1]]['name']; // assign buddies
							people[min_dist_agent_indices_k[1]]['assigned_buddy'] <- people[min_dist_agent_indices_k[0]]['name']; // assign buddies
							add min_dist_agent_indices_k[0] to: buddy_indices;
							add min_dist_agent_indices_k[1] to: buddy_indices;
							add people[min_dist_agent_indices_k[0]]['name'] to: buddies; // add to list of agents already matched
							add people[min_dist_agent_indices_k[1]]['name'] to: buddies;	// add to list of agents already matched
							add buddies to: matched_agents;
							add buddy_indices to: matched_agents_indices;
							add people[min_dist_agent_indices_k[0]]['name'] to: matched_agents_check; // for simplified checking 
							add people[min_dist_agent_indices_k[1]]['name'] to: matched_agents_check;
						}
					}
				}
			}
			
			write(sample(matched_agents));
			if length(viable_matches) > 0 {
				loop k from: 0 to: length(viable_matches) - 1 {				
					point min_dist_index_k <- dist_matrix index_of viable_matches[k];
					list min_dist_agent_indices_k <- index_matrix[min_dist_index_k.x, min_dist_index_k.y];
					bool skip <- matched_agents_check contains_any [people[min_dist_agent_indices_k[0]]['name'],people[min_dist_agent_indices_k[1]]['name']];
					if skip = false { //check for agents already matched
						write "New agents: ";
						list buddies;
						list buddy_indices;
						people[min_dist_agent_indices_k[0]]['assigned_buddy'] <- people[min_dist_agent_indices_k[1]]['name']; // assign buddies
						people[min_dist_agent_indices_k[1]]['assigned_buddy'] <- people[min_dist_agent_indices_k[0]]['name']; // assign buddies
						add min_dist_agent_indices_k[0] to: buddy_indices;
						add min_dist_agent_indices_k[1] to: buddy_indices;
						add people[min_dist_agent_indices_k[0]]['name'] to: buddies; // add to list of agents already matched
						add people[min_dist_agent_indices_k[1]]['name'] to: buddies;	// add to list of agents already matched
						add buddies to: matched_agents;
						add buddy_indices to: matched_agents_indices;
						add people[min_dist_agent_indices_k[0]]['name'] to: matched_agents_check; // for simplified checking 
						add people[min_dist_agent_indices_k[1]]['name'] to: matched_agents_check;
					}	
				}
			}

			write(sample(matched_agents));
			
			//calculate common speed, waiting time, meeting location and separation point
			if length(matched_agents) > 0 {
				loop i from: 0 to: length(matched_agents)-1 {
					
					int ped1_index <- matched_agents_indices[i][0];
					int ped2_index <- matched_agents_indices[i][1];
					write(sample(ped1_index));
					write(sample(ped2_index));
					
					people[ped1_index]['flag_active'] <- 0; //newly included 01.10.2020
					people[ped2_index]['flag_active'] <- 0; //newly included 01.10.2020
					
					people[ped1_index]['buddy_gender'] <- people[ped2_index]['gender'];
					people[ped2_index]['buddy_gender'] <- people[ped1_index]['gender'];
					
					people[ped1_index]['flag_matched'] <- 1;
					people[ped2_index]['flag_matched'] <- 1;
					
					int common_walk_start <- max(people[ped1_index]['start_walk'], people[ped2_index]['start_walk']); // find latter start time
					people[matched_agents_indices[i][0]]['modified_start_walk'] <- common_walk_start;
					people[matched_agents_indices[i][1]]['modified_start_walk'] <- common_walk_start;
					
					point ped1_location <- people[ped1_index]['location'];
					write sample(ped1_location);
					point ped2_location <- people[ped2_index]['location'];
					write sample(ped2_location);
					
					point ped1_dest <- people[ped1_index]['pt_destination'];
					write sample(ped1_dest);
					point ped2_dest <- people[ped2_index]['pt_destination'];
					write sample(ped2_dest);
					
					if ped1_dest = ped2_dest {
						people[ped1_index]['flag_diffdest'] <- 0;
						people[ped2_index]['flag_diffdest'] <- 0;
						people[ped1_index]['separation_point'] <- ped1_dest;
						people[ped2_index]['separation_point'] <- ped2_dest;
					}
					else {
						people[ped1_index]['flag_diffdest'] <- 1;
						people[ped2_index]['flag_diffdest'] <- 1;
						path shortest_path_between_destinations <- path_between (the_graph, ped1_dest, ped2_dest);
						list<geometry> check_segments_2 <- shortest_path_between_destinations.segments;
						float shortest_path_length_between_destinations <- shortest_path_between_destinations.shape.perimeter;
						float dist_from_seppoint <- 0.0;
						point separation_point;
						loop line over: check_segments_2 {
							dist_from_seppoint <- dist_from_seppoint + line.perimeter;
							if dist_from_seppoint >= 0.5 * shortest_path_length_between_destinations {
								separation_point <- line;
								break;
							}
						}
						people[ped1_index]['separation_point'] <- separation_point;
						people[ped2_index]['separation_point'] <- separation_point;
					}
					
					if ped1_location = ped2_location {
						float shortest_path_length_to_buddy<- 0.0;
						write sample(shortest_path_length_to_buddy);
						point meeting_point <- ped1_location;
						write sample(meeting_point);
						float dist_to_meetingpoint <- 0.0;
					} 
					else {
						path shortest_path_to_buddy <- path_between (the_graph, ped1_location, ped2_location);
						people[ped1_index]['shortest_path_to_buddy'] <- shortest_path_to_buddy;
						people[ped2_index]['shortest_path_to_buddy'] <- shortest_path_to_buddy;
										
						list<geometry> check_segments <- shortest_path_to_buddy.segments;
						write sample(check_segments);
						people[ped1_index]['check_segments'] <- check_segments;
						people[ped2_index]['check_segments'] <- check_segments;					
						
						float shortest_path_length_to_buddy <- shortest_path_to_buddy.shape.perimeter;
						write sample(shortest_path_length_to_buddy);
						people[ped1_index]['shortest_path_length_to_buddy'] <- shortest_path_length_to_buddy;
						people[ped2_index]['shortest_path_length_to_buddy'] <- shortest_path_length_to_buddy;
						
						float dist_to_meetingpoint <- 0.0; // deducing meeting point of buddies and their distance to it					
						point meeting_point;
						loop line over: check_segments {
							dist_to_meetingpoint <- dist_to_meetingpoint + line.perimeter;
							if dist_to_meetingpoint >= 0.5 * shortest_path_length_to_buddy {
								meeting_point <- line;
								break;
							}
						}
						write sample(meeting_point);
						people[ped1_index]['meeting_point'] <- meeting_point;
						people[ped2_index]['meeting_point'] <- meeting_point;	
						path shortest_path_to_meetingpt_ped1 <- path_between (the_graph, ped1_location, meeting_point);	//newly included 01.10.2020
						path shortest_path_to_meetingpt_ped2 <- path_between (the_graph, ped2_location, meeting_point);	//newly included 01.10.2020
						people[ped1_index]['dist_to_meetingpoint'] <- shortest_path_to_meetingpt_ped1.shape.perimeter; 	//newly included 01.10.2020	
						people[ped2_index]['dist_to_meetingpoint'] <- shortest_path_to_meetingpt_ped2.shape.perimeter;	//newly included 01.10.2020
					}
						
					float ped1_speed <- people[ped1_index]['speed'];
					float ped2_speed <- people[ped2_index]['speed'];
					float common_speed <- min(ped1_speed, ped2_speed); // find slower walking speed, assign to both
					people[ped1_index]['speed'] <- common_speed;
					people[ped2_index]['speed'] <- common_speed;
				}
			}
		}		
	}
	
	// WRITING THE RESULTS TO A CSV FILE
	reflex write_to_csv  when: nbpeople = 0 and flag_write = 0 {

		flag_write <- 1;	
		save people to: "../models/results_nbpeople500_ptstopsearchdist500to1000/result_"+filename+"_buddydist"+distance_threshold+"_ptstopsearchdist"+ptstop_search_distance+".csv" type:"csv" rewrite: true;
		write "End of simulation for parameter value "+ptstop_search_distance;
	}
	
	reflex end_simulation when: cycle = end_cycle { //providing sufficient time to complete other batches
		
		if flag_write = 1 {
			write "END OF ALL BATCHES";
			do pause;
		}
		else{
			end_cycle <- cycle + 10; //allowing some more time for completion
		}

	}
	
}


species road  {
	float weight;
	float length;
	rgb color <- #grey ;
	aspect base {
		draw shape color: color ;
	}
}

species nodepoints {
	aspect geom {
		draw circle(20) color: #red border: #black;		
	}
}

species stopscsv {
	string osmid;
	string type;
	list routes;
	point location;
	int flag_mapmatched <- 0;
	int type_index;
		
	aspect geom {
		if type = 'bus_stop' {
			draw square(40) color: #orange;
		}
		else if type = 'tram_stop' {
			draw square(40) color: #green;
		}
		else {
			draw square(40) color: #blue;
		}
			
	}
}

species people skills:[moving] {
	
	geometry my_path;
	geometry my_path_2;
	geometry my_path_3;
	geometry my_path_4;
	
	point location;
	point the_target;

	float r <- rnd (0.0,1.0);
	float z <- normal_inverse(r,mean_speed,stdev_speed) with_precision(2);
	float speed <- mean_speed + z*stdev_speed;
	
	float total_dist <- 0.0 ;	
	float dist_alone <- 0.0 ;	
	float dist_towards_buddy <- 0.0 ;
	float dist_with_buddy <- 0.0 ;
	float dist_after_separation <- 0.0 ;
	
	int start_walk ;
	int end_walk;
	int walk_duration;
	int modified_start_walk; // modified starting time of walk
	int actual_waiting_time <- 0; // waiting time for the agent for matching
	int max_waiting_time <- rnd (min_max_waiting_time/60,max_max_waiting_time/60); // maximum time (in minutes) for which the agent will wait before giving up
	
	list<geometry> segments; 
	list<point> pts; 

	list nearby_agents; // retrieves the nearby agents calculated in reflex info time at cycle 1
	list mod_nearby_agents; // modified number of nearby agents during matching
	string assigned_buddy; // retrieves the assigned walking buddy

	
	path shortest_path_to_buddy; // shortest path to buddy's start location
	geometry shortest_path_to_buddy_shape;
	float shortest_path_length_to_buddy; // shortest path length to buddy's start location
	point meeting_point; // meeting point of assigned buddies
	float dist_to_meetingpoint; // shortest path to meeting point
	path the_path_to_meetingpoint; 
	path the_path_together;
	path the_path;
	path the_path_after_separation;
	road current_road;
	path shortest_path;
	float shortest_path_length;

	int flag_active <- 0;
	int flag_matched <- 0;
	int flag_give_up <- 0;
	int flag_diffdest <- 0;
	int flag_reached <- 0; 
	int flag_reached_seppoint <- 0;
	list<people> neighbour_agents;
	list active_users;

	geometry search_area <- circle(ptstop_search_distance,location);
	list var0;
	list var1;
	bool start_walk_share;
	bool still_together; 
	int trigger_walk;
	
	list<stopscsv> nearby_stops;
	int no_of_nearby_stops;
	agent<stopscsv> mystop;
	point pt_destination;
	int travelmode_choice <- rnd_choice([tram_choiceprob,(1-tram_choiceprob)]); //if 0, then chooses tram, if 1, then chooses bus
	
	// AGENTS CHOOSING DESTINATION FROM THE LIST OF POSSIBLE PT STOPS
	reflex choose_destination when: cycle = 0 {
		nearby_stops <- list(stopscsv) at_distance (ptstop_search_distance);
		nearby_stops >>- nearby_stops select (each.type_index != travelmode_choice);
		no_of_nearby_stops <- length(nearby_stops);
		if no_of_nearby_stops > 1 { // choose randomly from any of the stops within the given threshold
			mystop <- any(nearby_stops);// where each.type_index = travelmode_choice);
			pt_destination <- mystop.location;
			write(sample(self));
			write(sample(no_of_nearby_stops));
			write(sample(nearby_stops));
			write(sample(mystop));
			write "";
		}
		else { // if no stops within threshold, choose the nearest one
			mystop <- list(stopscsv) closest_to(self);
			pt_destination <- mystop.location;
			write(sample(self));
			write(sample(no_of_nearby_stops));
			write(sample(nearby_stops));
			write(sample(mystop));
			write "";
		}
		
		if pt_destination != location {
			shortest_path <- path_between (the_graph, location, pt_destination);
			write(sample(shortest_path));
			shortest_path_length <- shortest_path.shape.perimeter;
		}
		else {
			shortest_path_length <- 0.0;
		}
	}
	
	// BECOMING ACTIVE IN THE SYSTEM BY PUTTING IN REQUEST WHEN READY TO START WALK
	reflex become_active when: start_walk = current_min and flag_matched = 0{ //updated 1.10.2020
		flag_active <- 1;
	}

	// WAITING TO GET MATCHED AFTER BECOMING ACTIVE IN THE SYSTEM
	reflex waiting when: flag_active = 1 and assigned_buddy = nil {
		actual_waiting_time <- current_min - start_walk;
	}
	
	
	// AGENTS GIVE UP WHEN WAITING TIME EXCEEDS THEIR MAXIMUM WAITING TIME THRESHOLD
	reflex give_up when: actual_waiting_time = max_waiting_time and assigned_buddy = nil {
		flag_active <- 0;
		flag_give_up <- 1;
		modified_start_walk <- start_walk + actual_waiting_time;
	}
	
	// AGENTS MOVE ALONE TOWARDS THEIR FINAL DESTINATION WHEN NOT MATCHED
	reflex move_alone when: flag_active = 0  and flag_give_up = 1 { // walk towards final destination alone if no matches found
		the_path <- goto (target: self.pt_destination, on: the_graph, return_path: true);
		list<geometry> segments <- the_path.segments;
		loop line over: segments {
			total_dist <- total_dist + line.perimeter;
			dist_alone <- dist_alone + line.perimeter;
		}
		
		if (the_path != nil and the_path.shape != nil) {
			list<point> pts <- (the_path.segments accumulate each.points);
			if (first(pts) != last(pts)) {
				my_path <-my_path = nil ? the_path.shape :union(my_path,the_path.shape);
			}	
		}		
	}
	
	// STARTING TO MOVE WITH ASSIGNED COMPANION FROM ORIGIN IF BOTH HAVE SAME ORIGIN
	reflex move_with_buddy_from_origin when: shortest_path_length_to_buddy = 0.0 and modified_start_walk <= current_min and flag_matched = 1 {
		flag_active <- 0;
		trigger_walk <- 1; 
		var0 <- self neighbors_at(0) collect each.name;
		start_walk_share <- var0 contains assigned_buddy;
	}
	
	// WALKING COMPANIONS MOVING TOGETHER 
	reflex move_together when: trigger_walk = 1 { // walk towards final destination after meeting

		var1 <- self neighbors_at(50) collect each.name; //checking for separation when destinations are different
		still_together <- var1 contains assigned_buddy;

		the_path_together <- goto (target: pt_destination, on: the_graph, return_path: true);
		list<geometry> segments <- the_path_together.segments;

		loop line over: segments {
			total_dist <- total_dist + line.perimeter;
			if still_together  = false {  // added 02.10.2020
				dist_after_separation <- dist_after_separation + line.perimeter; 
			}
			else {
				dist_with_buddy <- dist_with_buddy + line.perimeter;
			}		
		}
		
		if (the_path_together != nil and the_path_together.shape != nil) {
			list<point> pts <- (the_path_together.segments accumulate each.points);
			if (first(pts) != last(pts)) {
				my_path_3 <-my_path_3 = nil ? the_path_together.shape :union(my_path_3,the_path_together.shape);
			}	
		}		
	}
	
	reflex move_from_seppoint_to_dest when: flag_diffdest = 1 and flag_reached_seppoint = 1 {
		
		the_path_after_separation <- goto (target: pt_destination, on: the_graph, return_path: true);
		list<geometry> segments <- the_path_after_separation.segments;
		loop line over: segments {
			total_dist <- total_dist + line.perimeter;
//			dist_alone <- dist_alone + line.perimeter; 
			dist_after_separation <- dist_after_separation + line.perimeter; 
		}
		if (the_path_after_separation != nil and the_path_after_separation.shape != nil) {
			list<point> pts4 <- (the_path_after_separation.segments accumulate each.points);
			if (first(pts4) != last(pts4)) {
				my_path_4 <-my_path_4 = nil ? the_path_after_separation.shape :union(my_path_4,the_path_after_separation.shape);
			}	
		}	
	}
	
	// AGENTS WALKING TOWARDS ASSIGNED MEETING POINT
	reflex move_to_meet when: assigned_buddy != nil and (modified_start_walk <= current_min and trigger_walk = 0) and flag_matched = 1 {	// walk towards meeting point
		flag_active <- 0;	 
		the_path_to_meetingpoint <- goto (target: meeting_point, on: the_graph, return_path: true);	
		list<geometry> segments <- the_path_to_meetingpoint.segments;
		loop line over: segments {
			total_dist <- total_dist + line.perimeter;
			dist_towards_buddy <- dist_towards_buddy + line.perimeter;
		}	
		if (the_path_to_meetingpoint != nil and the_path_to_meetingpoint.shape != nil) {
			list<point> pts2 <- (the_path_to_meetingpoint.segments accumulate each.points);
			if (first(pts2) != last(pts2)) {
				my_path_2 <-my_path_2 = nil ? the_path_to_meetingpoint.shape :union(my_path_2,the_path_to_meetingpoint.shape);
			}	
		}
		
		var0 <- self neighbors_at(0) collect each.name;
		start_walk_share <- var0 contains assigned_buddy;
		if start_walk_share = true and self.location = meeting_point { // walk towards destination is triggerred only if both peds are at the meeting point
			trigger_walk <- 1; // once it becomes 1, it always stays 1 even if start walk share is false		
		}
	}

	// AGENTS HAVE REACHED THEIR DESTINATION
	reflex walk_end when: location = pt_destination and flag_reached = 0 {
		end_walk <- current_min;
		walk_duration <- (end_walk - modified_start_walk);
		flag_reached <- 1;
		nbpeople <- nbpeople - 1;
	}

	aspect base {
		if self.location != pt_destination {
			if flag_active = 1 {
				draw triangle(30) color: #orange border: #black;
			}
			else if flag_matched = 1 {
				draw triangle(30) color: #green border: #black;
			}
			else if flag_give_up = 1 {
				draw triangle(30) color: #red border: #black;
			}
			else {
				draw triangle(30) color: rgb(#orange,5) border: #black;
			}		
			
		}
		else{
			draw triangle(30) color: rgb(#blue,5) border: #black;
		}
		draw my_path color: #blue;
		draw my_path_2 color: #red;
		draw my_path_3 color: #green;
		draw my_path_4 color: #orange;
	}

}


experiment ped_traffic type: gui {
	
//	parameter "Shapefile for pedestrian network:" var: edges_shapefile category: "Input files" ;
//	parameter "CSV file for PT stops data:" var: stops_csv category: "Input files" ;
//	parameter "CSV file for population data:" var: population_input category: "Input files" ;
	parameter "Simulation number" var: sim_number category: "Model: General" ;

	parameter "Number of people" var: nbpeople_init category: "People: General" ;

	
	parameter "PT stop search distance" var: ptstop_search_distance category: "People: Thresholds"; // min: 0.0 #m max: 1000.0 #m;	
	parameter "Euclidian distance threshold for matchmaking" var: distance_threshold category: "People: Thresholds"; // min: 0.0 #m max: 1000.0 #m;
	parameter "Maximum waiting time (lower limit)" var: min_max_waiting_time category: "People: Thresholds" min: 0 #mn max: 5#mn;
	parameter "Maximum waiting time (upper limit)" var: max_max_waiting_time category: "People: Thresholds" min: 5 #mn max: 15#mn ;
	
	parameter "Mean walking speed" var: mean_speed category: "People" min: 3.0 #km/#h max: 4.5 #km/#h;
	parameter "Standard deviation of walking speed" var: stdev_speed category: "People" min: 0.5 #km/#h max: 1.0 #km/#h;
	parameter "Probability of tram as the travel mode" var: tram_choiceprob category: "People" min: 0.0 max: 1.0;
		
	output {
//		layout #split parameters: true navigator: false editors: false consoles: true toolbars: false tray: false tabs: false;
		display "Environment" type:opengl {
			species road aspect: base ;
			species people aspect: base ;
			species nodepoints aspect: geom;
			species stopscsv aspect: geom;
		}
		
//		display "Waiting times" {
//    		chart "Waiting times by agent" type: histogram 
//    		title_font_size: 20 {
//			datalist people collect each.name value:people collect each.actual_waiting_time;		
//    		}	
//		}
//		
//		display "Walking distance" {
//    		chart "Walking distances by agent" type: histogram 
//    		title_font_size: 20 {
//			datalist people collect each.name value:people collect each.total_dist;		
//    		}	
//		}
//		
//		display "Detour" {
//    		chart "Detour lengths by agent" type: histogram 
//    		title_font_size: 20 {
//			datalist people collect each.name value:people collect (each.total_dist - each.shortest_path_length);		
//    		}	
//		}
//		
//		display "Waiting time distribution" {
//		    chart "Waiting time distribution" type: histogram 
//		    title_font_size: 20 
//		    y_range:[0, nbpeople_init] {
//			datalist (distribution_of(people collect each.actual_waiting_time,2,0,10) at "legend") 
//			    value:(distribution_of(people collect each.actual_waiting_time,2,0,10) at "values");		
//		    }
//		}
//		
//		display "Detour length distribution" {
//		    chart "Detour length distribution" type: histogram 
//		    title_font_size: 20 
//		    y_range:[0, nbpeople_init] {
//			datalist (distribution_of(people collect (each.total_dist - each.shortest_path_length),10,0,1000) at "legend") 
//			    value:(distribution_of(people collect (each.total_dist - each.shortest_path_length),10,0,1000) at "values");		
//		    }
//		}
//		
//		display "Total walking distance distribution" {
//		    chart "Total walking distance distribution" type: histogram 
//		    title_font_size: 20 
//		    y_range:[0, nbpeople_init] {
//			datalist (distribution_of(people collect each.total_dist,10,0,1000) at "legend") 
//			    value:(distribution_of(people collect each.total_dist,10,0,1000) at "values");		
//		    }
//		}
//		
//		display "Walking distance towards buddy distribution" {
//		    chart "Walking distance towards buddy distribution" type: histogram 
//		    title_font_size: 20 
//		    y_range:[0, nbpeople_init] {
//			datalist (distribution_of(people collect each.dist_towards_buddy,10,0,1000) at "legend") 
//			    value:(distribution_of(people collect each.dist_towards_buddy,10,0,1000) at "values");		
//		    }
//		}
//		
//		display "Walking distance with buddy distribution" {
//		    chart "Walking distance with buddy distribution" type: histogram 
//		    title_font_size: 20 
//		    y_range:[0, nbpeople_init] {
//			datalist (distribution_of(people collect each.dist_with_buddy,10,0,1000) at "legend") 
//			    value:(distribution_of(people collect each.dist_with_buddy,10,0,1000) at "values");		
//		    }
//		}
//		
//		display "Matching rate" {
//		    chart "Matching rate" type: histogram 
//		    title_font_size: 30 
//		    tick_font_size: 20 
//		    label_font_size: 20 
//		    legend_font_size: 50 
//		    x_label:'Status of matching'
//			y_label:'User count'{
//				data 'Share of users who have been matched' value: (people count (each.flag_matched = 1)/nbpeople_init)*100;	
//				data 'Share of users who gave up' value: (people count (each.flag_give_up = 1)/nbpeople_init)*100;		
//		    }
//		}	
//		
//		display "Count of users by status" {
//    		chart "Number of users" type: series 
//    		title_font_size: 30 
//    		tick_font_size: 20 {
//			data 'Number of users actively searching for companion' value: people count (each.flag_active = 1);	
//			data 'Number of users who have been matched' value: people count (each.flag_matched = 1);	
//			data 'Number of users who gave up' value: people count (each.flag_give_up = 1);	
//    		}	
//		}
//		
//		display "Travel mode choice" {
//		    chart "Travel mode choice" type: histogram 
//		    title_font_size: 30 
//		    tick_font_size: 20 
//		    label_font_size: 20 
//		    legend_font_size: 50 
//		    x_label:'Choice of mode'
//			y_label:'User count'{
//				data 'Tram' value: people count (each.travelmode_choice = 0);	
//				data 'Bus' value: people count (each.travelmode_choice = 1);		
//		    }
//		}	
		
		monitor "Current minute" value: current_min refresh: every(1#cycle);
		monitor "Number of users currently active" value: people count (each.flag_active = 1);
		monitor 'Number of users who have been matched' value: people count (each.flag_matched = 1);
		monitor "Number of users remaining" value: nbpeople refresh: every(1#cycle);
		monitor 'Number of users who gave up' value: people count (each.flag_give_up = 1);	
		monitor 'Buddy distance threshold' value: distance_threshold ;
		monitor 'PT stop distance threshold' value: ptstop_search_distance ;
		monitor "Current minute" value: current_min refresh: every(1#cycle);
		
		monitor 'Matching rate(%)' value: (people count (each.flag_matched = 1)/nbpeople_init)*100;
		monitor 'Mean waiting time (minutes)' value: mean(people collect each.actual_waiting_time);
		monitor 'Mean trip length (metres)' value: mean(people collect each.total_dist);
		monitor 'Mean shortest distance (m)' value: mean(people collect each.shortest_path_length);
		
	}
}


experiment batch_ped_traffic type: gui {
	
//	parameter "Shapefile for pedestrian network:" var: edges_shapefile category: "Input files" ;
//	parameter "CSV file for PT stops data:" var: stops_csv category: "Input files" ;
//	parameter "CSV file for population data:" var: population_input category: "Input files" ;
	parameter "Simulation number" var: sim_number category: "Model: General" ;

	parameter "Number of people" var: nbpeople_init category: "People: General" ;
//	parameter "Proportion of male agents" var: male_to_total_ratio category: "People: Demographics" min: 0.0 max: 1.0; 
	
	parameter "PT stop search distance" var: ptstop_search_distance category: "People: Thresholds"; // min: 0.0 #m max: 1000.0 #m;	
	parameter "Euclidian distance threshold for matchmaking" var: distance_threshold category: "People: Thresholds"; // min: 0.0 #m max: 1000.0 #m;
	parameter "Maximum waiting time (lower limit)" var: min_max_waiting_time category: "People: Thresholds" min: 0 #mn max: 5#mn;
	parameter "Maximum waiting time (upper limit)" var: max_max_waiting_time category: "People: Thresholds" min: 5 #mn max: 15#mn ;
	
	parameter "Mean walking speed" var: mean_speed category: "People" min: 3.0 #km/#h max: 4.5 #km/#h;
	parameter "Standard deviation of walking speed" var: stdev_speed category: "People" min: 0.5 #km/#h max: 1.0 #km/#h;
	parameter "Probability of tram as the travel mode" var: tram_choiceprob category: "People" min: 0.0 max: 1.0;
	
	// We create supplementary simulations using the species name 'gridnetworkdynamic_model' (automatically created from the name of the model + '_model')
	init {
		create walksharing_model with: [distance_threshold::200.0];
		create walksharing_model with: [distance_threshold::300.0];
		create walksharing_model with: [distance_threshold::400.0];
		create walksharing_model with: [distance_threshold::500.0];
	}
		
	output {

		monitor 'Filename' value: filename ;	
		monitor 'Buddy distance threshold' value: distance_threshold ;
		monitor "Current minute" value: current_min refresh: every(1#cycle);
		monitor "Number of users remaining" value: nbpeople refresh: every(1#cycle);		
		monitor 'Number of users who have been matched' value: people count (each.flag_matched = 1);
//		monitor 'Number of users who gave up' value: people count (each.flag_give_up = 1);	
		
	}
}