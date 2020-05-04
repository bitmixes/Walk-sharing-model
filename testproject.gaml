/***
* Name: testproject
* Author: dbhowmick
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model testproject

/* Insert your model definition here */

global {
	file edges_shapefile <- file("C:/Users/dbhowmick/Documents/Unimelb/Papers Articles and more/walk-sharing/data/Wyndham Vale/edges/edges.shp");
	file nodes_shapefile <- file("C:/Users/dbhowmick/Documents/Unimelb/Papers Articles and more/walk-sharing/data/Wyndham Vale/nodes/nodes.shp");	
	geometry shape <- envelope(edges_shapefile);
	graph the_graph;
	
	int nbpeople <- 10;
//	float speed <- 3.0 #km/#h;
//	float min_speed <- 3.0 #km/#h;
//	float max_speed <- 5.0 #km/#h;
	float mean_speed <- 3.5 #km/#h;
	float stdev_speed <- 0.5 #km/#h;
	int min_walk_start <- 1;
	int max_walk_start <- 61;
	float step <- 10 #second;
	int current_min update: (time / 60);	
	
	init {
		create road from: edges_shapefile ;
		map<road, float> weights_map <- road as_map (each:: each.shape.perimeter);
		the_graph <- as_edge_graph(road) with_weights weights_map;
		create dest from: nodes_shapefile ;
		create people number:nbpeople {
			write "Name: " + people.name;
			float r <- rnd (0.0,1.0);
			write "random probability: " + r;
			float z <- normal_inverse(r,mean_speed,stdev_speed) with_precision(2);
			write "z: " + z;
			speed <- mean_speed + z*stdev_speed;
			write "speed from normal distribution: " + speed;
			start_walk <- min_walk_start + rnd (max_walk_start - min_walk_start) ; //choice of value between 1 to 61 minutes
			write "Start walk: " + max_walk_start;
//			write self.location;
			
		}
		write sample(people.attributes);
		
	}
	
	reflex info_time {
		write "\n-------------------------------------------";
		//the global variable cycle gives the current step of the simulation
		write "cycle: " + cycle;
		
		//the global variable time gives the current duration (in seconds) since the beginning of the simulation: time = cycle * step
		//The value of the time facet can be seen - in a date-time presentation - in the top-left green info panel (click on the number of cycle to see the time value). 
		//All models, otherwise stated, start at the ISO date of 1970-01-01T00:00Z. 
		//For more realistic accounts of dates, see the Date type and Real dates model in the same folder.
		write "time: " + time;
		write "number of agents left: " + nbpeople;		
		if cycle = 1 {		
			write "agents left: ";
			int agents_with_no_nearby_agents <- 0;
			loop i from: 0 to: nbpeople-1 {
				write "name: " + people[i]['name'];
				write "location: " + people[i]['location'];
				write "walk starting at: " + people[i]['start_walk'];
				list neighbour_agents <- people[i] neighbors_at(400);
				write "Agents starting within 400 metres radius: " + neighbour_agents;
				write "Number of agents within 400 metres radius: " + length(neighbour_agents);
				int neighbour_count <- length(neighbour_agents);
				if neighbour_count = 0 {
					agents_with_no_nearby_agents <- agents_with_no_nearby_agents + 1;
				}
				list neighbour_agents_2 <- neighbour_agents;
				if length(neighbour_agents) > 0 {				
					loop j from: 0 to: neighbour_count-1 {
						write "Walk start of agent " + neighbour_agents[j] + " is " + neighbour_agents[j]['start_walk'];
						int time_diff <- int(people[i]['start_walk']) - int(neighbour_agents[j]['start_walk']);
						write " Absolute time diff: " + abs(time_diff) + " with agent: " + neighbour_agents[j];
						if  abs (time_diff) > 15 {
							write "Removal of agent: " + neighbour_agents[j]['name'];
							neighbour_agents_2 <- neighbour_agents_2 - neighbour_agents[j];
						}
					}
					people[i]['nearby_agents'] <- neighbour_agents_2; // stores nearby agents in the agent dataframe nearby agents column
					write "Agents starting within 400 metres radius and 15 minutes: " + people[i]['nearby_agents'];
					//write "Type: " + type_of(people[i]['nearby_agents']); // type list
					write "Number of agents within 400 metres radius and 15 minutes: " + length(people[i]['nearby_agents']);
				}
				write "";
			}
			
			int match_set_count <- nbpeople;
			list match_set_names <- people collect each.name;
			write " Match set: " + match_set_names;
			write " Match set count: " + match_set_count;
			list agents_matched_already;
			loop while: match_set_count > agents_with_no_nearby_agents {
//			loop i from: 0 to: 10 {				
				string min_matched_agent_name;
				list min_matched_agent_neighbours;
				string assigned_partner;
				int min_matches <- 100000000;				
				int m;
				loop k from: 0 to: nbpeople-1 {
					int flag <- 0;
									
					if length(agents_matched_already) > 0 { // avoid agents already matched while looping through match set
//						write "Bla bla";
						loop j from: 0 to: length(agents_matched_already) - 1 {
							if agents_matched_already[j] = people[k]['name'] {
								flag <- 1; // indicating the agent has already been matched
								write "Flag = 1 for " + agents_matched_already[j];
							}
						}
					}					
					
					if flag = 0 { // indicating that the agent in question has not been matched previously
						list neighbour_agents_3 <- people[k]['nearby_agents'];
						if min_matches > length(neighbour_agents_3) and length(neighbour_agents_3) > 0 {
							m <- k;
							write "Temp min at index: " + k;	
							min_matched_agent_name <- people[k]['name'];
							write "Temp min_matched_agent_name: " + min_matched_agent_name;
							min_matched_agent_neighbours <- people[k]['nearby_agents'];
							min_matches <- length(min_matched_agent_neighbours);
							if length(agents_matched_already) > 0 {
								list already_matched;
								loop m from: 0 to: length(agents_matched_already) - 1 { // avoid assigning buddy agents previously matched while looping through min_matched_agent_neighbours
									loop n from: 0 to: min_matches - 1 {
										if agents_matched_already[m] = min_matched_agent_neighbours[n]['name'] {
											already_matched <- already_matched + min_matched_agent_neighbours[n];
//											flag1 <- 1;
										}
//										else {
//											flag1 <- 0;
//										}
									}
								}
								min_matched_agent_neighbours <- min_matched_agent_neighbours - already_matched;
								write "Modified min_matched_agent_neighbours: " + min_matched_agent_neighbours;
								people[k]['mod_nearby_agents'] <- min_matched_agent_neighbours;
							}
							else {
								people[k]['mod_nearby_agents'] <- min_matched_agent_neighbours;
							}
						}
					}			
				}
				
				if length(min_matched_agent_neighbours) > 0 {
					write "min_matched_agent_name: " + min_matched_agent_name;
					write "min_matched_agent_neighbours: " + min_matched_agent_neighbours;
					write "min_matches: " + min_matches;
				
					assigned_partner <- min_matched_agent_neighbours[0]['name'];
					write "assigned_partner: " + assigned_partner;
					
					match_set_count <- match_set_count - 2;
					write "Match set count:: " + match_set_count;
					
					agents_matched_already <- agents_matched_already + [min_matched_agent_name,assigned_partner];
					write "agents_matched_already: " + agents_matched_already;
					int var1 <- match_set_names index_of min_matched_agent_name;
					write "Index of min_matched_agent: " + var1;
					int var2 <- match_set_names index_of assigned_partner;
					write "Index of assigned_partner: " + var2;
					people[var1]['assigned_buddy'] <- assigned_partner;
					people[var2]['assigned_buddy'] <- min_matched_agent_name;
					write "";
				}
				else {
					agents_matched_already <- agents_matched_already + min_matched_agent_name; // actually agent has not found a match, but we assign him too already match set for ease in calculation
					match_set_count <- match_set_count - 1;
				}
					
			}
			write "\n MATCHING COMPLETE";
			
			int modified_start_walk ;
			path shortest_path_to_buddy ;
			float shortest_path_length_to_buddy ;
			list match_set_names_2 <- people collect each.name;
			loop i from: 0 to: nbpeople-1 {
				bool skip <- match_set_names_2 contains people[i]['name'];
				if people[i]['assigned_buddy'] != nil and skip = true {
					string ped1_name <- people[i]['name'];
					write " Agent: " + ped1_name;
					string ped2_name <- people[i]['assigned_buddy'];
					write " Buddy: " + ped2_name;
					int ped1_index <- i;
					int ped2_index <- match_set_names index_of ped2_name;
					write " ped1_index: " + ped1_index;
					write " ped2_index: " + ped2_index;					
					int ped1_start <- people[ped1_index]['start_walk'];
					int ped2_start <- people[ped2_index]['start_walk'];
					write " ped1_start: " + ped1_start;
					write " ped2_start: " + ped2_start;
					int common_walk_start <- max(ped1_start, ped2_start); // find latter start time
					
					people[ped1_index]['modified_start_walk'] <- common_walk_start; // assign latter start time to both as their modified walk start time
					people[ped2_index]['modified_start_walk'] <- common_walk_start;
					write " modified_start_walk for both: " + common_walk_start;
					
					if ped1_start < ped2_start {
						people[ped1_index]['waiting_time'] <- ped2_start - ped1_start;
						people[ped2_index]['waiting_time'] <- 0;
					}
					else {
						people[ped1_index]['waiting_time'] <- 0;
						people[ped2_index]['waiting_time'] <- ped1_start - ped2_start; // assign waiting time for the agents, 0 for latter, time diff for former
					}
				
					point ped1_location <- people[ped1_index]['location'];
					write " Agent location: " + ped1_location;
					point ped2_location <- people[ped2_index]['location'];
					write " Buddy location: " + ped2_location;
					path shortest_path_to_buddy <- path_between (the_graph, ped1_location, ped2_location);
					write " shortest_path_to_buddy: " + shortest_path_to_buddy;
					people[ped1_index]['shortest_path_to_buddy'] <- shortest_path_to_buddy;
					people[ped2_index]['shortest_path_to_buddy'] <- shortest_path_to_buddy;
					
					geometry shortest_path_to_buddy_shape <- shortest_path_to_buddy.shape;
					write " shortest_path_to_buddy_shape: " + shortest_path_to_buddy_shape;
					people[ped1_index]['shortest_path_to_buddy_shape'] <- shortest_path_to_buddy_shape;
					people[ped2_index]['shortest_path_to_buddy_shape'] <- shortest_path_to_buddy_shape;
					
					list<geometry> check_segments <- shortest_path_to_buddy.segments;
					write " check_segments: " + check_segments;
					write " check_segments_length: " + length(check_segments);
					people[ped1_index]['check_segments'] <- check_segments;
					people[ped2_index]['check_segments'] <- check_segments;					
					
					float shortest_path_length_to_buddy <- shortest_path_to_buddy.shape.perimeter;
					write " shortest_path_length_to_buddy: " + shortest_path_length_to_buddy;
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
					write " meeting_point: " + meeting_point;
					people[ped1_index]['meeting_point'] <- meeting_point;
					people[ped2_index]['meeting_point'] <- meeting_point;					
					write " dist_to_meetingpoint: " + dist_to_meetingpoint;
					people[ped1_index]['dist_to_meetingpoint'] <- dist_to_meetingpoint;
					people[ped2_index]['dist_to_meetingpoint'] <- shortest_path_length_to_buddy - dist_to_meetingpoint;
					
					float ped1_speed <- people[ped1_index]['speed'];
					float ped2_speed <- people[ped2_index]['speed'];
					float common_speed <- min(ped1_speed, ped2_speed); // find slower walking speed, assign to both
					people[ped1_index]['speed'] <- common_speed;
					people[ped2_index]['speed'] <- common_speed;
					write " common_speed: " + common_speed;
					
//					list var0 <- path(shortest_path_to_buddy) points_along ([0.5]);
					match_set_names_2 <- match_set_names_2 - people[i]['name'];
					match_set_names_2 <- match_set_names_2 - people[ped2_index]['name'] ;
					write " ";
					
				}
				else {
//					people[i]['modified_start_walk'] <- people[i]['start_walk'];
					match_set_names_2 <- match_set_names_2 - people[i]['name'] ;
				}
			}
			write "\n COMMON START TIME, WAITING TIME, SHORTEST PATH TO BUDDY, COMMON SPEED CALCULATION COMPLETE";
						
		}
		
		if cycle = 0 {
			write "agents left: ";
			write "All";
		}
		
	}

	
//	reflex save_result when: (nbpeople > 0) {
//		save ("cycle: "+ cycle + ", nbpeople: " + nbpeople
//			+ ", minEnergyPreys: " + (prey min_of each.energy)
//			+ "; maxSizePreys: " + (prey max_of each.energy) 
//	   		+ "; nbPredators: " + nb_predators           
//	   		+ "; minEnergyPredators: " + (predator min_of each.energy)          
//	   		+ "; maxSizePredators: " + (predator max_of each.energy)) 
//	   		to: "results.txt" type: "text" rewrite: (cycle = 0) ? true : false;
//	}
	
	reflex end_simulation  when: nbpeople = 0 {
		do pause;
	}
	
}

species road  {
	int nb_tot;
	int nb_current <- 0 update: length(people at_distance 0.1) ;
	aspect base {
		draw shape color: #grey ;
	}
	aspect show_nb_tot {
		draw shape + (nb_tot / 10.0)  color: #red ;
	}
	aspect show_nb_current {
		draw shape + (0.1 + nb_current / 5.0) color: #green ;
	}
}


species dest {
	aspect geom{
		draw shape;// color: #blue;
	}
}



species people skills:[moving] {
	
	image_file my_icon <- image_file ("../includes/pedestrian-icon-4.png") ;
	
	geometry my_path;
	geometry my_path_2;
	geometry my_path_3;
	point location <- any_location_in(one_of(dest));
	point the_target <- {2589.21,2565.98,0}; // common destination shopping centre
	
	float total_dist <- 0.0 ;	
	float dist_alone <- 0.0 ;	
	float dist_towards_buddy <- 0.0 ;
	float dist_with_buddy <- 0.0 ;
	int start_walk ;
	int end_walk;
	int walk_duration;
	list<geometry> segments; 
	list<point> pts; 
	int flag <-1;
	list nearby_agents; // retrieves the nearby agents calculated in reflex info time at cycle 1
	list mod_nearby_agents; // modified number of nearby agents during matching
	string assigned_buddy; // retrieves the assigned walking buddy
	int modified_start_walk; // modified starting time of walk
	int waiting_time; // waiting time for the agent for matching
	path shortest_path_to_buddy; // shortest path to buddy's start location
	geometry shortest_path_to_buddy_shape;
	float shortest_path_length_to_buddy; // shortest path length to buddy's start location
	point meeting_point; // meeting point of assigned buddies
	float dist_to_meetingpoint; // shortest path to meeting point
	path the_path_to_meetingpoint; 
	path the_path_together;
	path the_path;
//	float real_speed;
	road current_road;
//	map<road, float> roads_knowledge;

	path shortest_path <- path_between (the_graph, location, the_target);
	float shortest_path_length <- shortest_path.shape.perimeter;
	
	reflex die when: shortest_path_length >= 1500.0 {
		nbpeople <- nbpeople - 1;
		do die ;
	}
	
	geometry search_area <- circle(400,location);
	list var0;
	bool start_walk_share; 
	int trigger_walk <- 0;
	
	reflex move when: assigned_buddy = nil  and start_walk <= current_min { // walk towards final destination alone if no matches found
		the_path <- goto (target: the_target, on: the_graph, return_path: true);
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
	
	reflex move_together when: trigger_walk = 1 { // walk towards final destination after meeting
		the_path_together <- goto (target: the_target, on: the_graph, return_path: true);
		list<geometry> segments <- the_path_together.segments;
		loop line over: segments {
			total_dist <- total_dist + line.perimeter;
			dist_with_buddy <- dist_with_buddy + line.perimeter;
		}
		
		if (the_path_together != nil and the_path_together.shape != nil) {
			list<point> pts <- (the_path_together.segments accumulate each.points);
			if (first(pts) != last(pts)) {
				my_path_3 <-my_path_3 = nil ? the_path_together.shape :union(my_path_3,the_path_together.shape);
			}	
		}		
	}
	
	reflex move_to_meet when: assigned_buddy != nil and (modified_start_walk <= current_min and trigger_walk = 0) {		 // walk towards meetiung point
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
	

	
//	list var0 <- agents_overlapping(self) collect each.name;
//	list var0 <- self neighbors_at(0) collect each.name;
//	people var0 <- people closest_to self;	
//	bool met_with_buddy <- var0.name = assigned_buddy;
//	list nearby_agents <- self neighbors_at(400);
//	list nearby_agents <- neighbour_agents_2;

	
//	reflex move when:  start_walk <= current_min {	// for single movement
////	reflex move when:  var0.name = assigned_buddy {	
//		path the_path <- goto (target: the_target, on: the_graph, return_path: true);
//		list<geometry> segments <- the_path.segments;
//		loop line over: segments {
//			dist <- dist + line.perimeter;
//		}
//		
//		road my_road <- road closest_to self;
//		if (my_road != current_road) {
//			my_road.nb_tot <- my_road.nb_tot + 1;
//			current_road <- my_road;
//		}
//		
//		if (the_path != nil and the_path.shape != nil) {
//			list<point> pts <- (the_path.segments accumulate each.points);
//			if (first(pts) != last(pts)) {
//				my_path <-my_path = nil ? the_path.shape :union(my_path,the_path.shape);
//			}	
//		}	
//	}
	
	reflex walk_end when: self.location = the_target and flag = 1 {
		nbpeople <- nbpeople - 1;
		end_walk <- current_min;
		walk_duration <- (end_walk - modified_start_walk);
		flag <- 0;
		//do die;// returns: end_walk; // works for sim pausing, but cannot see info regarding valid pedestrians after death
		//int end_walk <- self die [];
	}

	aspect base {
//		draw circle(10) color: #red border: #black;
		draw my_icon size: 30;
		draw my_path color: #blue;
		draw my_path_2 color: #red;
		draw my_path_3 color: #green;
//		draw shortest_path.shape color: #magenta;
//		draw search_area color: rgb (255,0,0,25);
	}

	
}


experiment ped_traffic type: gui {
	parameter "Shapefile for the roads:" var: edges_shapefile category: "GIS" ;
	parameter "Number of people agents" var: nbpeople category: "People" ;
//	parameter "minimum walking speed" var: min_speed category: "People" min: 3 #km/#h ;
//	parameter "maximum walking speed" var: max_speed category: "People" max: 6 #km/#h;
	parameter "mean walking speed" var: mean_speed category: "People" min: 3 #km/#h ;
	parameter "standard deviation of walking speed" var: stdev_speed category: "People" max: 6 #km/#h;
		
	output {
		display city_display type:opengl {
			species road aspect: base ;
			species people aspect: base ;
			species dest aspect: geom;
		}
//		display road_nb_tot type:opengl {
//			species road aspect: show_nb_tot ;
//		}
//		display road_nb_current type:opengl {
//			species road aspect: show_nb_current ;
//		}
		monitor current_minute value: current_min refresh: every(1#cycle);
		
		display "total_distance" {
	    	chart "total_distance" type: series    {
			datalist (people collect each.name) value: (people collect each.total_dist);
	    	}
	    }
	    display "dist_alone" {
	    	chart "dist_alone" type: series  {
			datalist (people collect each.name) value: (people collect each.dist_alone);
	    	}
	    }
	    display "dist_towards_buddy" {
	    	chart "dist_towards_buddy" type: series  {
			datalist (people collect each.name) value: (people collect each.dist_towards_buddy);
	    	}
	    }
	    display "dist_with_buddy" {
	    	chart "dist_with_buddy" type: series  {
			datalist (people collect each.name) value: (people collect each.dist_with_buddy);
	    	}
	    }
//	    display "starting_time_distribution" {
//	    	chart "my_chart" type: histogram {
//			datalist (distribution_of(people collect each.start_walk,20,1,61) at "legend") value:(distribution_of(people collect each.start_walk,20,1,61) at "values");		
//	    	}
//	    }
//	    display "walking_speed_distribution" {
//	    	chart "my_chart" type: histogram {
//			datalist (distribution_of(people collect each.speed,50,0.9,1.3) at "legend") value:(distribution_of(people collect each.speed,50,0.9,1.3) at "values");		
//	    	}	
//		}


		display "distance_bar_chart" type:java2D {
	    	chart "my_chart" type: histogram //style:stack
	    	y_range:[0,2000]
	    	x_label:'Agent name'
	    	y_label:'total_dist'
//	    	series_label_position: onchart
	    	{
//				datalist
//					legend: people collect each.name
//					value: [people collect each.dist_alone]
////					accumulate_values: true	
//					style: stack
//					color: #blue;	
//				datalist 
//					legend: people collect each.name
//					value: [people collect each.dist_towards_buddy]
////					accumulate_values: true	
////					style: stack
//					color: #red;	
				datalist
					legend: people collect each.name //people collect each.name //
					value: people collect each.total_dist; //people collect each.total_dist //list(people collect each.total_dist) //
//					accumulate_values: true	
//					style: stack
//					color: #green;
	    	}	
		}
	}
}