;;total coronavirus cases
globals [
  M
  N
  increase      ;;increase，Determine if the total number of cases has increased
  signal1
  add-infection
  cure
  test-probability
  day
]

turtles-own
[
  susceptible
  exposed
  infection
  recover
  virus-check-timer
  Y   ;;个人线上情绪
]

to setup
  clear-all
  set-default-shape turtles "circle"
  ;; make the initial network of two turtles and an edge
  make-node nobody        ;; first node, unattached
  make-node turtle 0      ;; second node, attached to first node
  reset-ticks
end


to go
  ;; new edge is green, old edges are gray
  ask links [ set color gray ]
  make-node find-partner         ;; find partner & use it as attachment
                                 ;; point for new node
  tick
  if layout? [ layout ]
end

to setup2
  set M 0           ;;Global media strength
  set N 0           ;;Maximum number of infected
  set increase false
  set add-infection 0
  set cure 0
  set test-probability 0
  set day 0
  set contact 20
  ask turtles[
    become-susceptible
  ]

  ask turtles [               ;; loop
  set Y random-normal 0 0.1
  set susceptible true
  set exposed false
  set infection false
  set recover false

  ]
  ask n-of initial-outbreak-size turtles
    [ become-exposed ]  ;; Initializes a specified number of exposures

  reset-ticks
end

to set-all-susceptible
  ask turtles [
    set color blue
  ]
end

to remove-infection
  ask turtles with [exposed or infection]
    [become-susceptible
  ]


end

to spread
  if all? turtles [(not infection) and (not exposed)] ;;If all states are not infected, stop running
    [ stop ]
  panic-media
  ask turtles
  [
    update-panic
    set virus-check-timer 0
  ]
  ask turtles
  [
     set virus-check-timer virus-check-timer + 1                      ;;For each 'go', "how many time steps have passed since the last virus check" is recorded once
     if (virus-check-timer >= virus-check-frequency and susceptible)  ;; Get regular check-ups
       [ set virus-check-timer 0 ] ;; 置0
  ]


  ;;调用函数，实现感染者传播病毒
  spread-virus
  ;;调用函数，使得暴露者转化为感染者
  convert-infection


  set day day + 1
  if day > isolation-date [set contact 3]
  if day > day-release-exposed
  [
    ifelse day < 100
    [set test-probability day / 100]
    [set test-probability 1.00]
  ]

  let Ni count turtles with [infection] + test-probability * count turtles with[exposed]            ;;Record the number of infected patients in this round

   ifelse Ni >  N
  [                                    ;;Determine whether the number of confirmed cases is bigger
    set increase true
  ]
  [set increase false]
  set N Ni



   ;; Call the function to realize the rehabilitation of the exposed and infected
  do-virus-checks

  tick
end



;; used for creating a new node
to make-node [old-node]
  create-turtles 1
  [
    set color blue
    if old-node != nobody
      [ create-link-with old-node [ set color green ]
        ;; position the new node near its partner
        move-to old-node
        fd 8
      ]
  ]
end

;; This code is the heart of the "preferential attachment" mechanism, and acts like
;; a lottery where each node gets a ticket for every connection it already has.
;; While the basic idea is the same as in the Lottery Example (in the Code Examples
;; section of the Models Library), things are made simpler here by the fact that we
;; can just use the links as if they were the "tickets": we first pick a random link,
;; and than we pick one of the two ends of that link.
to-report find-partner
  report [one-of both-ends] of one-of links
end

;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count link-neighbors ]
  ]
  [
    ask turtles [ set size 1 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end


; Copyright 2005 Uri Wilensky.
; See Info tab for full copyright and license.


;; -------------------------------------------------------------------------------

to update-panic                         ;;Panic about updating personal information


   ifelse infection
  [
    panic-infection    ;;Panic changes after infection -Y
  ]

  [
    panic-neighbors    ;;Panic from the neighbors
    if random-float 1 < get-media-rate and not infection          ;;Get panic from the media with probability K and correct your panic
    [
      let degree count link-neighbors
      let x (Y * degree + M) / degree
      set Y (e ^ x - e ^ ( -1 * x)) / (e ^ x + e ^ ( -1 * x))                 ;;The more friends you have, the less effect the global media intensity has
    ]
  ]


  panic-reduce         ;;The natural decay rate of panic


end




to become-susceptible  ;; Individuals become susceptible
  set susceptible true
  set exposed false
  set infection false
  set recover false
  set color blue
end

to become-exposed  ;; Individuals become exposed
  set susceptible false
  set exposed true
  set infection false
  set recover false
  set color yellow
end

to become-infection  ;; The individual is infected
  set susceptible false
  set exposed false
  set infection true
  set recover false
  set color red
end



to become-recover  ;; Individuals acquire viral resistance
  set susceptible true
  set exposed false
  set infection false
  set recover true
  set color gray
  ask my-links [ set color gray - 2 ] ;; Grey out the edges of invalid nodes
end



to panic-infection                       ;;Panic changes after infection
  set Y random-float 0.1 + k
end

to panic-neighbors                    ;;Panic from the neighbors
  let Y-neighbor 0                                             ;;Calculation formula Numerator 
  let high-num-neighbors count link-neighbors with [Y > 0.6]   ;;Calculate the weight of a high-weight neighbor
  let low-num-neighbors count link-neighbors with [Y <= 0.6]   ;;Calculate the weights of low-weight neighbors
  let wight-neighbors high-num-neighbors * 10 + low-num-neighbors
  ask link-neighbors
  [
    ifelse Y > 0.6 [set Y-neighbor Y-neighbor + Y * 10 ]
                   [set Y-neighbor Y-neighbor + Y ]
  ]
  set Y Y-neighbor / wight-neighbors
end

to panic-media                          ;;Global media strength

    ifelse increase
  [
    ifelse (count turtles with [infection] + test-probability * count turtles with[exposed]) < 100
    [set M k / 5]
    [set M k / 2]
  ]       ;;If the number of cases increases, the global media intensity changes
  [set M 0]
end



to panic-reduce                          ;;The natural decay rate of panic
  set Y panic-reduce-rate * Y
end

to spread-virus ;; 健康人感染病毒
  let people count turtles
  let exposed_count count turtles with [exposed]
  let infection_count count turtles with [infection]
  let rate ((contact * exposed_infected * exposed_count + contact * infection_infected * infection_count) / people) ;;Can be optimized to reduce computational complexity
  let real_rate rate * (count turtles with [susceptible]) / people
  set signal1 real_rate
  ask turtles with [ susceptible and not recover ]
    [if random-float 100 < real_rate
      [become-exposed]]

    ;;[ ask turtles with [not recover]
    ;;    [ if random-float 100 < virus-spread-chance
    ;;        [ become-infection ] ] ]
end

to convert-infection  ;;A certain number of days from exposure to infection
  ask turtles with[exposed]
  [
    if random-normal -2 2 + incubation < virus-check-timer      ;;Using random numbers makes the disease more uniform
      [become-infection]
  ]


end



to do-virus-checks  ;; Recovery of exposed and infected persons
  ask turtles with [(infection or exposed) and virus-check-timer > 0]
  [
    if random 100 < recovery-chance  ;; There is a certain probability of healing or self-healing
    [
        become-recover
      ;;ifelse random 100 < gain-resistance-chance
      ;;  [ become-recover ]    ;;On the basis of cure, there is a certain probability of acquiring resistance to the virus
      ;;  [ become-susceptible ]  ;;People who are not lucky enough to acquire resistance to the virus become susceptible again
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
345
10
837
503
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-60
60
-60
60
0
0
1
ticks
60.0

PLOT
8
330
333
496
Degree Distribution (log-log)
log(degree)
log(# of nodes)
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "if not plot? [ stop ]\nlet max-degree max [count link-neighbors] of turtles\n;; for this plot, the axes are logarithmic, so we can't\n;; use \"histogram-from\"; we have to plot the points\n;; ourselves one at a time\nplot-pen-reset  ;; erase what we plotted before\n;; the way we create the network there is never a zero degree node,\n;; so start plotting at degree one\nlet degree 1\nwhile [degree <= max-degree] [\n  let matches turtles with [count link-neighbors = degree]\n  if any? matches\n    [ plotxy log degree 10\n             log (count matches) 10 ]\n  set degree degree + 1\n]"

PLOT
8
153
333
329
Degree Distribution
degree
# of nodes
1.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if not plot? [ stop ]\nlet max-degree max [count link-neighbors] of turtles\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-degree + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [count link-neighbors] of turtles"

BUTTON
6
25
72
58
NIL
setup
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
93
64
170
97
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

BUTTON
6
64
91
97
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
187
30
333
63
plot?
plot?
1
1
-1000

SWITCH
187
64
333
97
layout?
layout?
1
1
-1000

MONITOR
237
100
316
145
# of nodes
count turtles
3
1
11

BUTTON
7
102
109
135
redo layout
layout
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
115
102
225
135
resize nodes
resize-nodes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
847
10
1042
43
initial-outbreak-size
initial-outbreak-size
2
50
20.0
1
1
NIL
HORIZONTAL

SLIDER
652
523
847
556
virus-check-frequency
virus-check-frequency
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
849
196
1044
229
recovery-chance
recovery-chance
0.1
100
20.0
0.1
1
%
HORIZONTAL

BUTTON
850
399
923
432
NIL
setup2
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
964
397
1037
430
NIL
spread
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1277
549
1440
582
NIL
set-all-susceptible
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
1492
548
1634
581
NIL
remove-infection
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
848
121
1036
154
exposed_infected
exposed_infected
0
100
2.0
0.1
1
%
HORIZONTAL

SLIDER
849
159
1041
192
infection_infected
infection_infected
0
100
6.0
0.1
1
%
HORIZONTAL

INPUTBOX
848
53
1038
113
contact
3.0
1
0
Number

SLIDER
848
232
1043
265
incubation
incubation
0
25
6.0
1
1
NIL
HORIZONTAL

PLOT
1063
440
1714
814
The average Internet panic
time
panic
0.0
70.0
0.0
100.0
false
true
"" ""
PENS
"Internet panic" 1.0 0 -16383231 true "" "plot  100 * mean [Y] of turtles"

SLIDER
848
275
1040
308
panic-reduce-rate
panic-reduce-rate
0
1
0.95
0.01
1
NIL
HORIZONTAL

SLIDER
848
355
1043
388
get-media-rate
get-media-rate
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
848
312
1042
345
k
k
0
0.9
0.6
0.01
1
NIL
HORIZONTAL

MONITOR
1733
512
2871
557
min
count turtles with [infection]
2
1
11

MONITOR
1730
108
1931
153
NIL
count turtles with [infection]
17
1
11

MONITOR
1731
399
1850
444
NIL
increase
2
1
11

PLOT
1065
16
1716
391
Status
time
proportion of individuals / %
0.0
70.0
0.0
100.0
false
true
"" ""
PENS
"susceptible" 1.0 0 -13791810 true "" "plot (count turtles with [not infection and not recover]) / (count turtles) * 100"
"exposed" 1.0 0 -4079321 true "" "plot (count turtles with [exposed]) / (count turtles) * 100"
"infected" 1.0 0 -5298144 true "" "plot (count turtles with [infection]) / (count turtles) * 100"
"recover" 1.0 0 -16514813 true "" "plot (count turtles with [recover]) / (count turtles) * 100"

PLOT
1758
728
2319
1057
media-foucs
time
media-intensity
0.0
200.0
0.0
1.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot M"

INPUTBOX
858
474
1013
534
isolation-date
25.0
1
0
Number

INPUTBOX
858
552
1013
612
day-release-exposed
100.0
1
0
Number

MONITOR
1740
461
1864
506
NIL
test-probability
17
1
11

MONITOR
1738
578
1972
623
NIL
add-infection
17
1
11

MONITOR
1739
644
1796
689
NIL
N
17
1
11

@#$#@#$#@
## WHAT IS IT?

In some networks, a few "hubs" have lots of connections, while everybody else only has a few.  This model shows one way such networks can arise.

Such networks can be found in a surprisingly large range of real world situations, ranging from the connections between websites to the collaborations between actors.

This model generates these networks by a process of "preferential attachment", in which new network members prefer to make a connection to the more popular existing members.

## HOW IT WORKS

The model starts with two nodes connected by an edge.

At each step, a new node is added.  A new node picks an existing node to connect to randomly, but with some bias.  More specifically, a node's chance of being selected is directly proportional to the number of connections it already has, or its "degree." This is the mechanism which is called "preferential attachment."

## HOW TO USE IT

Pressing the GO ONCE button adds one new node.  To continuously add nodes, press GO.

The LAYOUT? switch controls whether or not the layout procedure is run.  This procedure attempts to move the nodes around to make the structure of the network easier to see.

The PLOT? switch turns off the plots which speeds up the model.

The RESIZE-NODES button will make all of the nodes take on a size representative of their degree distribution.  If you press it again the nodes will return to equal size.

If you want the model to run faster, you can turn off the LAYOUT? and PLOT? switches and/or freeze the view (using the on/off button in the control strip over the view). The LAYOUT? switch has the greatest effect on the speed of the model.

If you have LAYOUT? switched off, and then want the network to have a more appealing layout, press the REDO-LAYOUT button which will run the layout-step procedure until you press the button again. You can press REDO-LAYOUT at any time even if you had LAYOUT? switched on and it will try to make the network easier to see.

## THINGS TO NOTICE

The networks that result from running this model are often called "scale-free" or "power law" networks. These are networks in which the distribution of the number of connections of each node is not a normal distribution --- instead it follows what is a called a power law distribution.  Power law distributions are different from normal distributions in that they do not have a peak at the average, and they are more likely to contain extreme values (see Albert & Barabási 2002 for a further description of the frequency and significance of scale-free networks).  Barabási and Albert originally described this mechanism for creating networks, but there are other mechanisms of creating scale-free networks and so the networks created by the mechanism implemented in this model are referred to as Barabási scale-free networks.

You can see the degree distribution of the network in this model by looking at the plots. The top plot is a histogram of the degree of each node.  The bottom plot shows the same data, but both axes are on a logarithmic scale.  When degree distribution follows a power law, it appears as a straight line on the log-log plot.  One simple way to think about power laws is that if there is one node with a degree distribution of 1000, then there will be ten nodes with a degree distribution of 100, and 100 nodes with a degree distribution of 10.

## THINGS TO TRY

Let the model run a little while.  How many nodes are "hubs", that is, have many connections?  How many have only a few?  Does some low degree node ever become a hub?  How often?

Turn off the LAYOUT? switch and freeze the view to speed up the model, then allow a large network to form.  What is the shape of the histogram in the top plot?  What do you see in log-log plot? Notice that the log-log plot is only a straight line for a limited range of values.  Why is this?  Does the degree to which the log-log plot resembles a straight line grow as you add more nodes to the network?

## EXTENDING THE MODEL

Assign an additional attribute to each node.  Make the probability of attachment depend on this new attribute as well as on degree.  (A bias slider could control how much the attribute influences the decision.)

Can the layout algorithm be improved?  Perhaps nodes from different hubs could repel each other more strongly than nodes from the same hub, in order to encourage the hubs to be physically separate in the layout.

## NETWORK CONCEPTS

There are many ways to graphically display networks.  This model uses a common "spring" method where the movement of a node at each time step is the net result of "spring" forces that pulls connected nodes together and repulsion forces that push all the nodes away from each other.  This code is in the `layout-step` procedure. You can force this code to execute any time by pressing the REDO LAYOUT button, and pressing it again when you are happy with the layout.

## NETLOGO FEATURES

Nodes are turtle agents and edges are link agents. The model uses the ONE-OF primitive to chose a random link and the BOTH-ENDS primitive to select the two nodes attached to that link.

The `layout-spring` primitive places the nodes, as if the edges are springs and the nodes are repelling each other.

Though it is not used in this model, there exists a network extension for NetLogo that comes bundled with NetLogo, that has many more network primitives.

## RELATED MODELS

See other models in the Networks section of the Models Library, such as Giant Component.

See also Network Example, in the Code Examples section.

## CREDITS AND REFERENCES

This model is based on:
Albert-László Barabási. Linked: The New Science of Networks, Perseus Publishing, Cambridge, Massachusetts, pages 79-92.

For a more technical treatment, see:
Albert-László Barabási & Reka Albert. Emergence of Scaling in Random Networks, Science, Vol 286, Issue 5439, 15 October 1999, pages 509-512.

Barabási's webpage has additional information at: http://www.barabasi.com/

The layout algorithm is based on the Fruchterman-Reingold layout algorithm.  More information about this algorithm can be obtained at: http://cs.brown.edu/people/rtamassi/gdhandbook/chapters/force-directed.pdf.

For a model similar to the one described in the first suggested extension, please consult:
W. Brian Arthur, "Urban Systems and Historical Path-Dependence", Chapt. 4 in Urban systems and Infrastructure, J. Ausubel and R. Herman (eds.), National Academy of Sciences, Washington, D.C., 1988.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2005).  NetLogo Preferential Attachment model.  http://ccl.northwestern.edu/netlogo/models/PreferentialAttachment.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2005 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2005 -->
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
set layout? false
set plot? false
setup repeat 300 [ go ]
repeat 100 [ layout ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment-test" repetitions="50" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>spread</go>
    <timeLimit steps="100"/>
    <metric>100 * mean [Y] of turtles</metric>
    <enumeratedValueSet variable="day-release-exposed">
      <value value="0"/>
      <value value="15"/>
      <value value="30"/>
      <value value="45"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="total" repetitions="50" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>spread</go>
    <metric>mean [Y] of turtles</metric>
    <enumeratedValueSet variable="day-release-exposed">
      <value value="100"/>
    </enumeratedValueSet>
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
