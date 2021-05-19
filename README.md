# Walk-sharing-model

## Exploring the viability of walk-sharing in outdoor urban spaces

Walking is the most common mode of travel, given its higher levels of accessibility, especially for short trips.
Researchers have suggested that walking has significant health benefits as well as community benefits, and more walkable urban spaces leads to sustainable and liveable communities.
However, challenging walking environments discourage people from walking.
Pedestrians, while walking alone, feel unsafe and vulnerable in certain outdoor spaces at certain times of the day.
Fear of crime has been cited as the most important barrier for which walking becomes unattractive at critical times of the day, even though walking might be convenient otherwise.
Pedestrian route and travel mode choice is often influenced by fear of crime and it forces- pedestrians to avail costlier alternatives, such as taking viable detours or abandoning walking altogether and switching to alternative forms of transport.
Fear of crime reduces the overall walkability of an urban area, reduces the time spent on walking, and thereby disrupts the benefits that are offered by walking.

Traditional approaches aimed at reducing the fear of crime amongst pedestrians are usually not cost-effective, never holistic and take significant time before coming into effect.
Existing research suggests that the absence of people is the major reason for pedestrians feeling fearful while walking through urban spaces at critical times of the day, even when infrastructural elements are conducive for walking.
Pedestrians feel safer when they walk with a companion as compared to walking alone in environments which they perceive as unsafe.
The presence of just another pedestrian nearby boosts natural vigilance, increases sense of security, reduces perceived risk and fear of crime.
People would walk more if they had a walking companion, such as a friend, a colleague, or a family member under critical circumstances.
But, a pedestrian is not guaranteed a walking companion under all critical circumstances.
To overcome this challenge, we have introduced walk-sharing, a hypothetical buddy-service, which is aimed at encouraging people to choose walking when it is viable, and not pursue alternative modes.
In walk-sharing, a potential pedestrian will get matched to another (assumed to be unknown to each other) so that they are able to walk together, instead of walking alone, and thus overcome any potential fear that arises out of seemingly unsafe walking environments.
We used an agent-based modelling platform GAMA (tailored for building spatially explicit agent-based simulations) to model walk-sharing, established proof of concept using synthetic data, and tested its technical viability under under real-world data-driven scenarios to understand the conditions in which walk-sharing will produce acceptable outcomes.

## What is walk-sharing?

In walk-sharing, a potential pedestrian will get matched to another so that they are able to walk together, instead of walking alone, and thus overcome any potential fear that arises out of seemingly unsafe walking environments. 
Walk-sharing makes an attempt to ensure such spatio-temporal overlap between at least two pedestrians so that they can walk together while trying to optimise related costs (waiting time, detour distance) for both.
This novel intervention is aimed at reviving the appeal of walking as a travel mode even at critical times of the day and the benefits that should follow thereafter.

## Scehmatic framework of walk-sharing

P_i and P_j are two pedestrians wanting to avail walk-sharing.
After getting matched with each other, they leave from their respective origins (O_i and O_j) and walk to their advised meeting point (MP_{ij}).
Consequently, they walk together and thus share their walk till their advised separation point (SP_{ij}).
From the separation point, they walk alone towards their respective destinations (D_i and D_j).
It must be noted that we have limited the scope of this study to pairwise walk-sharing only. 
This means that in any single walk-share, the maximum number of participants is restricted to two people.

![Schematic framework of walk-sharing](https://github.com/bitmixes/Walk-sharing-model/walksharing.jpg)

