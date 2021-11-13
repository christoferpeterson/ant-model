;;;;; types of Netlogo agents (turtles)
;; colors denote ant types and foraging status

; EXPLORING_FORAGER_COLOR (yellow) ants = foragers exploring for food
; orange ants = foragers carrying food to nest
; magenta ant = leader heading back to the nest after finding food;
; white ant = leader leading followers to the food
; brown ants = followers following leader during group recruitment
; MATURE_FOLLOWER_COLOR (violet) ants = mature followers that return independently to the nest
; blue dashes = trail-markers laid down by leaders or brown followers
; orange dashes = trail-markers laid down by successful foragers or mature followers

;
breed [foragers forager]
breed [leaders leader]
breed [followers follower]
breed [trail-markers trail-marker]

patches-own ;; variables accessible by the patches of the world
[ nest?                ; true inside nest, false outside
  nest-scent           ; strongest inside nest; used to guide ants back to nest
  nest-x nest-y
  food-source-center-x
  food-source-center-y
  food
]

trail-markers-own
[
  lifespan
]

globals  ;; accessible by all agents within the model
;; ticks mark the point when events occur
[ first-leader-tick
  first-follower-food-tick
  mass-recruitment-tick
  food-consumption-tick

  octopamine-level             ;; hormone level that corresponds with food quality to determine group-recruitment delay
  octopamine-level-delay-tick
  next-update

  mass-recruitment-delay
  next-mass-recruitment-update
  mass-recruitment-delay-tick

  LEADER_SPEED
  MAX_FOLLOWER_SPEED
  MIN_FOLLOWER_SPEED
  INITIAL_OCTOPAMINE_LEVEL

  EXPLORING_FORAGER_COLOR
  MATURE_FOLLOWER_COLOR
]

to setup
  clear-all
  set-default-shape turtles "bug"
  set-default-shape trail-markers "line half"
  create-foragers 5
  [set color yellow
    set size 2.25
    setxy 36 1]
  setup-patches
;;;                                 sets reporters to a default value of -1
  set INITIAL_OCTOPAMINE_LEVEL 10
  set first-leader-tick -1
  update-first-leader-tick
  set first-follower-food-tick -1
  update-first-follower-food-tick
  set mass-recruitment-tick -1
  update-mass-recruitment-tick
  set food-consumption-tick -1
  update-food-consumption-tick

  set octopamine-level INITIAL_OCTOPAMINE_LEVEL ; once a leader is created, octopamine level is "lowered" based on food-quality from the same default level
                                        ; then it decreases sequentially over time (every 20 ticks) until it reaches 0
  set next-update "none"
  set octopamine-level-delay-tick -1    ; once the octopamine-level reaches 0, a leader is allowed to recruit a follower

  set mass-recruitment-delay 100        ; once a follower reaches the food, the mass-recruitment-delay is lowered based on food-quality
  set mass-recruitment-delay-tick -1    ; group-recruitment (leader-follower stage) can continue until mass-recruitment-delay hits 0
  set next-mass-recruitment-update "none"

  set LEADER_SPEED 2
  set MAX_FOLLOWER_SPEED 2.0
  set MIN_FOLLOWER_SPEED 1.5

  set EXPLORING_FORAGER_COLOR yellow
  set MATURE_FOLLOWER_COLOR violet + 1

  reset-ticks
end

to setup-patches
ask patches
  [setup-nest
  setup-food
  setup-food-quality]
end

to setup-nest
  ;; setup coordinates for the center of the nest
  set nest-x 36
  set nest-y 1

  set nest? (distancexy 36 1) < 2      ;; set nest? variable to true inside the nest, false elsewhere
  set nest-scent 200 - distancexy 36 1 ;; spread a nest-scent over the whole world -- stronger near the nest
  if nest?                             ;; determine nest color
  [set pcolor brown]
end

to setup-food
  if (distancexy (0.85 * min-pxcor) (0.1 * min-pycor)) < 4.5  ;; determines position and size of the food patches
  [set food 10                                                ;; dictates the amount of food on each food-patch
    if food > 0
    [set pcolor cyan]]                                        ;; makes food cyan
  set food-source-center-x -32                                ;; sets coordinates for center of the food,
  set food-source-center-y -2                                 ;; which leaders learn + remember
end

to setup-food-quality  ;; patch procedure that randomly sets food-quality each time "setup" is run
  if food > 0
  [set food-quality one-of [0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]] ;; controllable with slider; 0 triggers no response
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go ;; triggered by the go button
  ask foragers
    [fd 1
     ifelse any? trail-markers
      [ifelse can-move? 1                          ;; if not at the edges
        [follow-trail-marker-path]
        [rt 180]]                                  ;; if at the edges, turn around
        [wiggle]                                   ;; wiggle (random-walk if there is no pheromone trail)
     look-for-food                                 ;; respond to food if found
     return-to-nest-and-food
      decrease-foragers-low-food
  ]
  ask leaders
      [wiggle
        lead                                       ;; go back and forth from the nest to the food, collecting followers
        mass-recruit-leaders]                      ;; transform into foragers once group-recruitment has finished -
                                                   ;; (mass-recruitment-delay = 0)
  ask followers
    [follow-leaders                                ;; walk behind leaders
      find-food                                    ;; first follower changes size to signal its presence on the food
      transition-to-mass-recruitment               ;; become mature-followers at the end of group recruitment
      return-to-nest-mass-recruitment-transition   ;; independently return to the nest once transformed into mature-followers
      mass-recruit                                 ;; mature followers transform into foragers at the nest

      if mass-recruitment-delay = 1 and food-quality < 0.9 and near-food
        [set color MATURE_FOLLOWER_COLOR
          uphill-nest-scent]]

  ask trail-markers
        [evaporate]

  ask patches
  [recolor-patch]                                                        ;; change color to signify food removal

  update-first-leader-tick
  update-first-follower-food-tick
  update-mass-recruitment-tick
  update-food-consumption-tick

  update-octopamine-level-delay-tick
  update-mass-recruitment-delay-tick

  if sum [food] of patches with [pcolor = cyan] = 0 and ticks > 0 and count trail-markers < 1000       ;; commands for the end of the model
  [ask foragers [if near-nest [die]]                                     ;; re-enter the nest if close
    if count foragers = 0 and ticks > 1000 and count trail-markers = 0 [stop]]                       ;; stops model when all foragers are in the nest

  tick
end

to look-for-food  ;; forager procedure
  let foods patches with [food > 0]  ;;
  let potential-leaders foragers-on foods

  if food > 0 and food-quality > 0
  [ifelse (not any? leaders) and (any? potential-leaders) and (count foragers <= 5)  ;; checks if any leaders exist and if object = true food
  [ ask one-of potential-leaders
    [ set breed leaders
     set color magenta]]  ;; transforms first forager to find food into the leader

    [set color orange]]  ;; identifies all subsequent successful foragers that reach the food after the leader
end

to return-to-nest-and-food  ;; forager procedure
  if color = orange                                        ;; directs movement of foragers who have found food
        [if food > 0 and mass-recruitment-tick < 0
          [set food food - .1]
          if food > 0 and mass-recruitment-tick > 0        ;; pick up more food during mass recruitment
          [set food food - 1]
          if food > 0 and sum [food] of patches with [pcolor = cyan] <= 20  ;; pick up large amount of food when only 2 food patches remain
          [set food food - 10]

         if count trail-markers > 200
             [lay-pheromone orange]         ;; reinforce trail
          uphill-nest-scent                               ;; directly returns to nest via dead reckoning
          if not can-move? 1 [rt 180]

        if near-nest                                      ;; "drop off" the food at the nest
          [set color EXPLORING_FORAGER_COLOR              ;; revert to original color to signal new foraging status
            set size 2.25
            ifelse mass-recruitment-delay > 0
            [IF COUNT FORAGERS > 5 and count foragers < 50
              [hatch-foragers 1]]                          ;; recruit an additional forager from the nest
            [hatch-foragers 1]
            follow-trail-marker-path
            fd 1
  ] ]
end

to lead  ;; leader procedure
  if color = magenta
    [fd 2               ;; walks quickly ahead of followers
      lay-pheromone blue
      uphill-nest-scent ;; dead-reckons

      if near-nest
      [set color white
        if (not (reached-max-followers followers food-quality)
           and (not any? followers with [color = MATURE_FOLLOWER_COLOR])
          and octopamine-level >= 20
           and (in-mass-recruitment-delay mass-recruitment-delay octopamine-level food-quality)
          )

          [
            hatch-followers 1
            [set color brown]
          ]
        ]
      ]

  if color = white
      [wiggle
        fd 2
        facexy food-source-center-x food-source-center-y        ;; head back to the food
        lay-pheromone blue
        if food > 0
          [set color magenta] ]
  if not can-move? 1 [rt 180]
end

to mass-recruit-leaders  ;; transition leaders to pheromone-following foragers
  if (not any? followers with [color = brown]) and (near-nest) and mass-recruitment-delay = 0   ;; transforms leaders into foragers during mass-recruitment
  [set breed foragers
    set color EXPLORING_FORAGER_COLOR
    hatch-foragers 1]
end

to follow-leaders  ;; follower procedure for group-recruitment
  if color = brown
  [face one-of leaders
    fd get-random-speed MIN_FOLLOWER_SPEED MAX_FOLLOWER_SPEED
    lay-pheromone blue                                          ;; reinforce pheromone trail
  ]
end

to find-food  ;; follower procedure that identifies first follower to reach food
  if near-food and (count followers = 1) and count foragers < 6
  [set size 1.75]
end

to transition-to-mass-recruitment  ;; follower procedure that makes them independent of leaders
  if near-food and (reached-max-followers followers food-quality) ;; once group-recruitment has finished (max number of followers for that food-quality reached)
  [set color MATURE_FOLLOWER_COLOR]
end

to return-to-nest-mass-recruitment-transition  ;; follower procedure that directs them back to nest to initate mass-recruitment
  if color = MATURE_FOLLOWER_COLOR
  [if food > 0
    [set food food - .1]
   lay-pheromone orange
   wiggle
   fd 1
   uphill-nest-scent]
end

to mass-recruit ;; follower procedure for transforming into foragers during mass-recruitment
  if near-nest and (color = MATURE_FOLLOWER_COLOR)
  [change-breed foragers
    if count foragers < 50 [hatch-foragers 1]]
end

to recolor-patch  ;; patch procedure
  ;; give color to nest and food sources
  ifelse nest?                          ;; nest? true --> color brown
  [ set pcolor brown ]
  [ ifelse food > 0                     ;; not nest, but has food
    [  set pcolor cyan ]
    [set pcolor black ] ]      ;; food/nest pheromone default to 0
end

to wiggle            ;; determines the "randomness" of the random walk by having the ants turn any angle up to 45 degress in either direction
  rt random 45
  lt random 45
  if not can-move? 1 [ rt 180 ]
end

to evaporate
 set lifespan lifespan - 1
 if(lifespan <= 0) [ die ]
end

to uphill-nest-scent  ;; dead-reckoning procedure that involves going towards the highest value of nest-scent
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

to follow-trail-marker-path     ;; directs ant movement toward the pheromone trail
  ifelse count foragers < 6    ;; at the beginning of recruitment, foragers random-walk
  [wiggle]

  [ifelse any? trail-markers-on patch-ahead 1 [fd 1 right random 20 left random 20]
    [ifelse (patch-left-and-ahead 30 1 = nobody) or (patch-right-and-ahead 30 1 = nobody)
      [wiggle]
      [if any? trail-markers-on patch-left-and-ahead 30 1 and (total-trail-markers-in-cone 10 -30 10 > total-trail-markers-in-cone 10 30 10)
        [lt 30]
      if (total-trail-markers-in-cone 10 30 10 > total-trail-markers-in-cone 10 -30 10) and any? trail-markers-on patch-right-and-ahead 30 1
        [rt 30]
        if total-trail-markers-in-cone 5 30 10 < 1 or total-trail-markers-in-cone 5 -30 10 < 1 [uphill-nest-scent]
  ]]]
end

to lay-pheromone [c]
  hatch-trail-markers 1
  [
    set size 1.0
    set color c
    set lifespan 700
  ]
end

to decrease-foragers-low-food
  if count patches with [pcolor = cyan] <= 5 and count patches with [pcolor = cyan] > 0 and count trail-markers < 1000 and count foragers > 250
  [ask n-of 250 foragers [die]]
end

;;; checks for any change in various statuses; if there is a change, it will be reported; these primarily correspond to the boxes on the left panel of the model interface

to update-first-leader-tick
  if first-leader-tick < 0
  [show count leaders
    if any? leaders
    [set first-leader-tick ticks]
  ]
end

to update-first-follower-food-tick
  let potential-recruiters followers with [size = 1.75]
  if first-follower-food-tick < 0
    [show count potential-recruiters
    if any? potential-recruiters
    [set first-follower-food-tick ticks]
  ]
end

to update-mass-recruitment-tick
  if mass-recruitment-tick < 0
  [show count leaders
    if not any? leaders and count foragers > 5
      [set mass-recruitment-tick ticks]
  ]
end

to update-food-consumption-tick
  let food-level sum [food] of patches with [pcolor = cyan]
  if food-consumption-tick < 0
  [show food-level
    if food-level < 1
    [ set food-consumption-tick ticks]
  ]
end

to update-octopamine-level-delay-tick
if (first-leader-tick > 0 and octopamine-level < 20)
  [
    show octopamine-level-delay-tick
    let time-elapsed ticks - first-leader-tick
    set octopamine-level INITIAL_OCTOPAMINE_LEVEL + (time-elapsed * (0.05 * exp (0.5 * food-quality)));

    if(octopamine-level >= 20)
    [
     set octopamine-level-delay-tick time-elapsed
    ]
  ]
end

to update-mass-recruitment-delay-tick  ;; delay mass recruitment based on food quality by extending group recruitment
  if first-follower-food-tick > 0
  [show mass-recruitment-delay-tick

    if mass-recruitment-delay = 100
    [set mass-recruitment-delay mass-recruitment-delay - (food-quality * 100)
      set next-mass-recruitment-update ticks + 40
      type "ticks = " type ticks type ", mass-recruitment-delay = " type mass-recruitment-delay print ", mass-recruitment-delay-reduction started"
]
    if (ticks = next-mass-recruitment-update) and mass-recruitment-delay > 1
    [set mass-recruitment-delay mass-recruitment-delay - 1
      set next-mass-recruitment-update ticks + 40

      type "ticks = " type ticks type ", mass-recruitment-delay = " print mass-recruitment-delay]

      if mass-recruitment-delay = 1
    [if not any? followers with [color = brown]
      [set mass-recruitment-delay mass-recruitment-delay - 1
        set mass-recruitment-delay-tick ticks]]

    ;if mass-recruitment-delay = 1 and ticks = next-mass-recruitment-update and food-quality = 0.9
    ;[set mass-recruitment-delay mass-recruitment-delay - 1
     ; set mass-recruitment-delay-tick ticks]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; reporters

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

to-report total-trail-markers-in-cone [cone-distance angle angle-width ] ; ant procedure - reports the total amount of trail-markers in cone
  rt angle
  let p count trail-markers in-cone cone-distance angle-width
  ;ask p [ show chemical ]
  lt angle
  report (p)
  if not any? p [report 0]
end

to-report leader-presence
  ifelse any? leaders
  [report first-leader-tick]
  [report -1]
end

to-report group-recruitment-initiation
  let recruited-ant followers with [size = 1.75]
ifelse any? recruited-ant
  [ report first-follower-food-tick ]
  [ report -1]
end

to-report leader-food-follower-difference
  ifelse first-leader-tick != -1 and first-follower-food-tick !=  -1
  [ report first-follower-food-tick - first-leader-tick]
  [ report -1 ]
end

to-report mass-recruitment-initiation
  ifelse not any? followers and not any? leaders
  [report mass-recruitment-tick]
  [report -1]
end

to-report food-consumption
  ifelse (sum [food] of patches with [pcolor = cyan] < 1 )
  [report food-consumption-tick]
  [report -1]
end

to-report reached-max-followers [f fq]
  if (count f >= 1 and fq < 0.3) ;; once group-recruitment has finished (max number of followers for that food-quality reached)
    [report true]
  if (count f >= 4 and fq > 0.2 and fq < 0.5)
    [report true]
  if(count f >= 6 and fq > 0.4 and fq < 0.7)
    [report true]
  if (count f >= 8 and fq > 0.6 and fq < 0.9)
    [report true]
  if(count f >= 10 and fq > 0.8)
    [report true]
  report false
end

to-report in-mass-recruitment-delay [mrd ol fq]
  if(mrd > 0 and ol >= 20 and fq < 0.9) or (ol >= 20 and food-quality > 0.8)
    [report true]
  report false
end

to-report get-random-speed [minSpeed maxSpeed]
  report (maxSpeed - (random-float 1 * (maxSpeed - minSpeed)))
end

to-report near-food
  if (distancexy food-source-center-x food-source-center-y <= 6)
    [report true]
  report false
end

to-report near-nest
  if (distancexy nest-x nest-y <= 2)
    [report true]
  report false
end

;; Change the breed of a turtle and update its visuals
;; b = the breed to change to

to change-breed [b]
  set breed b
  if b = foragers
  [
    set color yellow
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
327
10
1255
533
-1
-1
11.961
1
10
1
1
1
0
0
0
1
-38
38
-21
21
1
1
1
ticks
30.0

BUTTON
8
11
74
44
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
92
11
155
44
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
0
51
162
84
food-quality
food-quality
0
1
1.0
.1
1
NIL
HORIZONTAL

PLOT
5
321
181
453
food vs time
time
food
0.0
3000.0
0.0
120.0
true
false
"" ""
PENS
"food" 1.0 0 -5825686 true "" "plotxy ticks sum [food] of patches with [pcolor = cyan]"

MONITOR
263
406
325
451
Foragers
count foragers
17
1
11

MONITOR
187
355
256
400
Food-level
sum [food] of patches with [pcolor = cyan]
1
1
11

PLOT
6
464
245
623
Food + Foragers vs Time
ticks
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Foragers" 1.0 0 -5298144 true "" "plotxy ticks count foragers "
"Food" 1.0 0 -14439633 true "" "plotxy ticks sum [food] of patches with [pcolor = cyan]"

MONITOR
186
305
290
350
trail-marker level
count TRAIL-MARKERS
2
1
11

MONITOR
186
406
257
451
Followers
count followers
1
1
11

MONITOR
121
100
254
145
T1 group recruitment
group-recruitment-initiation
1
1
11

MONITOR
5
102
116
147
Leader presence
first-leader-tick
17
1
11

MONITOR
204
253
323
298
Food consumption
food-consumption
17
1
11

MONITOR
2
255
165
300
Mass recruitment initation
mass-recruitment-initiation
17
1
11

MONITOR
4
153
141
198
Time to Group Recruit
leader-food-follower-difference
17
1
11

MONITOR
261
102
328
147
OA level
octopamine-level
17
1
11

MONITOR
240
155
327
200
OA delay tick
octopamine-level-delay-tick
17
1
11

MONITOR
181
203
325
248
Mass recruitment delay
mass-recruitment-delay
17
1
11

MONITOR
2
204
172
249
Mass recruitment delay tick
mass-recruitment-delay-tick
17
1
11

PLOT
339
18
539
168
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count trail-markers"

@#$#@#$#@
## WHAT IS IT?

A model of T. immigrans (pavement ant) recruitment to a food source, beginning with group-recruitment, when a group of followers follows the leader to the food, and transitioning to mass-recruitment, when foraging is independent of the presence of the leader and based on the pheromone trail. 

## HOW IT WORKS

Yellow foragers start from the nest and begin exploring the world for the distant food. The first forager to reach the food becomes a leader and returns directly to the nest using dead-reckoning. Once octopamine-level reaches 0 and other conditions are met, the leader is allowed to recruit follower ants, which follow it back to the food. The leader lays down a pheromone trail (trail-markers), which is subsequently reinforced by its followers and successful foragers, which turn orange when they pick up food. Once the maximum number of followers has been collected, the followers break away from the leader, turning purple, and then return to the nest to become foragers. Group recruitment (when the leader recruits followers) continues until mass-recruitment-delay hits 0. At the nest, each successful forager starts a fresh search for food, turning yellow, and recruits an additional forager.

Foragers check for the presence of trail-markers directly ahead of them, and continue forward if they find it. If not, they check for the greatest amount of pheromone trail within a cone of vision to their right or left side and turn accordingly. If they are at the edge, they turn around. If they find no pheromone trail within their cones of vision, they head back to the nest and restart their search. If there is no pheromone trail or at least one round of group-recruitment has been completed, they walk randomly. Leaders, orange foragers and mature (violet) followers use dead-reckoning to return directly to the nest. When the food has been completely consumed, the trail-marker path evaporates, and foragers randomly wander to search for more food until they encounter the nest. 
(what rules the agents use to create the overall behavior of the model) 

## HOW TO USE IT

The food-quality slider controls how many follower ants are recruited, based on increments of 0.2 food-quality units. Foragers do not respond to food with a food-quality of 0, but instead wander randomly through the world. Various monitors report the ticks that correspond to the transformation of the first forager into the leader, when the first follower reaches the food, the time between these ticks, the time when mass-recruitment begins, and when the food is completely reduced. 

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

At higher food-qualities, the octopamine-level drops more rqpidly, so group-recruitment occurs sooner. The number of followers is determined by food quality, with the number of followers increasing with each increase in food quality increment (e.g 0.1 - 0.2 food quality). Group-recruitment continues until mass-recruitment-delay reaches 0, which means that it lasts longer for lower food qualities. 

(suggested things for the user to notice while running the model)

## THINGS TO TRY

What does altering the amount of food (at the beginning of the code) do? 

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL
Monitor the food level and plot food-level vs time. (suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

Different breeds - types of ants (by default in Netlogo, turtles)

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

The Ants model by Uri Wilensky and Ant Lines model by Uri Wilensky. (models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES
Original basis: 
Wilensky, U. (1997). NetLogo Ants model. http://ccl.northwestern.edu/netlogo/models/Ants. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.
Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.

Thanks to Jen B of StackOverflow for help with various aspects of the code, especially the leader breed transformation, and the Netlogo Users Group for help with various aspects of the model. Also thanks to Aaron Brandes, a CCL software developer from the Netlogo Users Group, for help with many of the reporters. Thanks to Ted Warsavage for help with troubleshooting and working through model logic. Most of all, thanks to Dr. Michael Greene of UC Denver, who directed this project.

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="6000"/>
    <metric>count foragers</metric>
    <metric>sum [food] of patches with [pcolor = cyan]</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-quality">
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="101"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="85"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8000"/>
    <metric>count foragers</metric>
    <metric>sum [food] of patches with [pcolor = cyan]</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-quality">
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="population" first="15" step="10" last="105"/>
    <steppedValueSet variable="diffusion-rate" first="85" step="5" last="95"/>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>leader-presence</metric>
    <metric>group-recruitment-initiation</metric>
    <metric>mass-recruitment-initiation</metric>
    <metric>food-consumption</metric>
    <metric>leader-food-follower-difference</metric>
    <steppedValueSet variable="food-quality" first="0.1" step="0.1" last="1"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
