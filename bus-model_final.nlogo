extensions [ bitmap ]

breed [viruses  virus]
breed [passengers passenger]
breed [staff-members staff-member]
breed [walls  wall]
breed [doors  door]
breed [windows  window]

globals [
  image

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;; CONVERSION RATIOS ;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  patch_to_meter ; patch to meter conversion ratio
  patch_to_feet  ; patch to feet conversion ratio
  fd_to_ftps     ; fd (patch/tick) to feet per second
  fd_to_mph      ; fd (patch/tick) to miles per hour
  tick_to_sec    ; ticks to seconds - usually 1
  new-passengers
  num-initial-infected ; number of initially infected passengers (10%)

  initial-passengers

]

viruses-own [
  lifespan ;virus has lifespan
  random?  ;virus can start moving randomly
]

passengers-own [
  ;binary variables
   infected?         ;has the person been infected with the disease?
   protected?        ;if true, the person is protected,it reduces the prob to get infected and makes the individual ovoid contact with other individuals
   in-seat?          ;if a person is in seat
   ;exited-passenger? ;if a person exited he bus
   new?              ;if a passenger is new, ticks > enter-time

  ;non-binary variables
   passenger-infect-time ;when a passenger is infected
   health            ;0-100, 100 is healthy
   target-exit       ;string variable stores "exit 1" (regular) or "exit 2" (emergency)
   stop-id           ;0, 1, 2 ... to indicate exit at which stop
   enter-time        ;time is in minutes
   exit-time         ;time is in minutes
   duration          ;time is in minutes (on bus duration)
]

staff-members-own [
  ;binary variables
   infected?         ;has the person been infected with the disease?
   protected?        ;if true, the person is protected,it reduces the prob to get infected and makes the individual ovoid contact with other individuals
   in-seat?          ;if a person is in seat
   exited?           ;if a person exited he bus

  ;non-binary variables
   staff-infect-time ;when a staff is infected
   health            ;0-100, 100 is healthy
   target-exit       ;string variable stores "exit 1" (regular) or "exit 2" (emergency)
   stop-id          ;0, 1, 2 ... to indicate exit at which stop

]

walls-own [
  wall-id
  ventilation?
]

doors-own [
  door-id
  opened?
]

windows-own [
  window-id
  opened?
]

patches-own [
  p-infected? ;; in the environmental variant, has the patch been infected?
  patch-infect-time ;; how long until the end of the patch infection?
  centroid?   ;;is it the centroid of a building?
  id          ;;if it is a centroid of a building, it has an ID that represents the building
  entrance    ;;nearest vertex on road. only for centroids.
  accessible? ;;only accessible at the door
  seat? ;; if a patch is a seat
]


to setup

  ;;; setup world ;;;
  clear-all

  print "----------------------------------------------------------"
  print "---               Background information               ---"
  print "----------------------------------------------------------"

  resize-world -10 170 -10 170
  ask patches [set pcolor white]
  ; make a smaller patch size so everything fits on the screen
  set-patch-size 4

  ; calculate patch/foot {CHANGE AFTER FINALIZING SIZES}
  set patch_to_feet 180 / 100; unit: patch/ft, 180 patch = 100 ft, (182 - 39) / 48 = 143/48 = 2.9792 (vertical)
  set patch_to_meter patch_to_feet / 3.281 ;unit: patch/m, 1 m = 3.281 ft
  set tick_to_sec 1.0 ; 1 minute = 1 tick(s)

  set fd_to_ftps patch_to_feet / tick_to_sec
  set fd_to_mph  fd_to_ftps * 0.682 ; 1ft/s = 0.682 mph
  ;set passenger-moving-speed 1

  print (list "fd_to_ftps (ft/s) = " precision fd_to_ftps 3 ","  "fd_to_mph (mph)  =  " precision fd_to_mph 3)

  ;set random number of initial passengers

  ;  if seat-capacity = 100 [set initial-passengers 4 + random 37]
  ;  if seat-capacity = 75  [set initial-passengers 4 + random 27]
  ;  if seat-capacity = 50  [set initial-passengers 4 + random 17]
  ;  if seat-capacity = 25  [set initial-passengers 4 + random  7]

  if seat-capacity = 100 [
  set initial-passengers 1 + (random 40) ;gives 1 - 40
  set num-initial-infected (round (initial-passengers * 0.1))
    if num-initial-infected = 0 [set num-initial-infected 1]
  ]

  if seat-capacity = 50 [
  set initial-passengers 1 + (random 20) ;gives 1 - 20
  set num-initial-infected 1 + random 2  ;gives 1 or 2
    if initial-passengers < num-initial-infected [set num-initial-infected initial-passengers]
  ]

  ; printing initial input values

  print (list "Number of all passengers      = " initial-passengers)
  print (list "Number of infected passengers = " num-initial-infected)
  print (list "simulation-length             = " simulation-length "hr")
  print (list "infection-probability         = " infection-probability "%")
  ;print (list "protected-population          = " protected-population  "%")
  ;print (list "stationary-infection-period   = " stationary-infection-period "min")
  ;print (list "passenger-moving-speed        = " passenger-moving-speed "patch")

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Calling various setup methods ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  set-geometry-layout-patches

  make-people

  initial-infect

  recolor ; infected/not infected patches and passengers

  make-viruses

  ;initialize the infected patches
  ask patches [ set p-infected? false ]

  ;setting up the windows
  if close-all-windows? [
    ask patches with [ (pxcor = 3 or pxcor = 157) and (pycor >= 10 and pycor <= 127) ] [ set pcolor black ]
  ]

  ;setting up the doors
  if close-all-doors? [
    ask patches with [ pxcor = 157 and (pycor >= 131 and pycor <= 155) ] [ set pcolor black ];door-right
    ask patches with [ pycor = 3   and (pxcor >= 67  and pxcor <= 93 ) ] [ set pcolor black ];door-bottom
  ]

  make-windows

  reset-ticks

end

to make-people

  create-passengers initial-passengers [
        set infected? false
        set shape "person"
        set color blue - 2
        set enter-time 0
        set stop-id (random simulation-length * 60 / average-travel-time ) + 1
        set exit-time stop-id * average-travel-time + (2 * stop-id - 1)
        if exit-time >= 720 [set exit-time 720]

        ;inserting max-time-onboard
        if (exit-time - enter-time) > max-time-onboard [
           set stop-id random ( floor ( max-time-onboard / (average-travel-time + 2) ) ) + 1
           ;if stop-id = 0 [set stop-id 1]
           set exit-time stop-id * average-travel-time + (2 * stop-id - 1) ]

        if exit-time >= 720 [set exit-time 720]
        set duration (exit-time - enter-time)
        set size 5.5
        set health 100
        set protected? true
        set in-seat? true
        set target-exit "exit 1"
        set new? true
        move-to one-of patches with [pcolor = orange and not any? passengers-here]
    ]

  create-staff-members num-staff-members [
        set infected? false
        set exited? false
        set shape "person service"
        set color pink
        set size 6.5
        set health 100
        move-to one-of patches with [pcolor = orange + 3]
        set in-seat? true
  ]

end

to make-viruses

  ;make viruses for initial infected passengers
  ask passengers with [infected?] [
    let x1 xcor
    let y1 ycor
    ;initial-infected passenger locations ...
        ;print (list passengers-here " (" x1 ", " y1 ")")
    ask patches with [pxcor = x1 and pycor = y1] [
      sprout-viruses num-virus-per-passenger [
        set shape "circle 2"
        set color green + 1
        set lifespan virus-lifespan
        set random? false
        setxy (x1 - 5 + random 10) (y1 - 5 + random 10) ;random btwn (-5,5)
        set size 2.5
      ]
    ]
  ]

end

to make-windows

  let num-open-window (round window-open / 100 * 20)

  ;let x-coord-window [3 157]
  ;let y-coord-window [10 22 33 45 57 69 81 92 104 115 127]

  let list-of-windows []
  let L_win length list-of-windows

  while [ L_win < num-open-window ][
    set list-of-windows lput (random 20) list-of-windows
    set list-of-windows remove-duplicates list-of-windows
    set L_win length list-of-windows
  ]

  ;print list-of-windows
  ;print sort list-of-windows

  ;open window-id = X
  if (member?  0 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  10 and pycor <  22) ] [ set pcolor white ] ]
  if (member?  1 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  22 and pycor <  33) ] [ set pcolor white ] ]
  if (member?  2 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  33 and pycor <  45) ] [ set pcolor white ] ]
  if (member?  3 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  45 and pycor <  57) ] [ set pcolor white ] ]
  if (member?  4 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  57 and pycor <  69) ] [ set pcolor white ] ]
  if (member?  5 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  69 and pycor <  81) ] [ set pcolor white ] ]
  if (member?  6 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  81 and pycor <  92) ] [ set pcolor white ] ]
  if (member?  7 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor >  92 and pycor < 104) ] [ set pcolor white ] ]
  if (member?  8 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor > 104 and pycor < 115) ] [ set pcolor white ] ]
  if (member?  9 list-of-windows) [ ask patches with   [ pxcor = 3 and (pycor > 115 and pycor < 127) ] [ set pcolor white ] ]

  if (member? 10 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  10 and pycor <  22) ] [ set pcolor white ] ]
  if (member? 11 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  22 and pycor <  33) ] [ set pcolor white ] ]
  if (member? 12 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  33 and pycor <  45) ] [ set pcolor white ] ]
  if (member? 13 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  45 and pycor <  57) ] [ set pcolor white ] ]
  if (member? 14 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  57 and pycor <  69) ] [ set pcolor white ] ]
  if (member? 15 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  69 and pycor <  81) ] [ set pcolor white ] ]
  if (member? 16 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  81 and pycor <  92) ] [ set pcolor white ] ]
  if (member? 17 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor >  92 and pycor < 104) ] [ set pcolor white ] ]
  if (member? 18 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor > 104 and pycor < 115) ] [ set pcolor white ] ]
  if (member? 19 list-of-windows) [ ask patches with [ pxcor = 157 and (pycor > 115 and pycor < 127) ] [ set pcolor white ] ]

end


;;;;;;;;;;;;;;;;;;;;;;;;
; Simulation - Go
;;;;;;;;;;;;;;;;;;;;;;;;

to go

  if ticks = (simulation-length * 60) ; all? passengers [ infected? ] or
  [
    print "----------------------------------------------------------"
    print "---            passengers related information          ---"
    print "----------------------------------------------------------"
    print "stop-id, infect-time, enter-time, exit-time, infected?";in-seat?,
    ask passengers [ print ( list stop-id passenger-infect-time enter-time exit-time infected? ) ];in-seat?
  ]
  ;if all? passengers [ infected? ] [ stop ]
  if ticks >= (simulation-length * 60) [stop]

  ;infection methods
  spread-infection
  recolor
  update-viruses

  ;exiting passengers
  exit-passengers

  tick ; this helps to count entering passengers

  ;entering passengers to seats
  enter-new-passengers

  ;this helps to count new passengers
  ask passengers with [enter-time < ticks] [set new? false]

  ;to-print

  move-viruses
end

to to-print

  print list "--- Time = " ticks
  ;print list "# exiting = " count passengers with [exit-time = ticks] ;count passengers with [shape = "person business"]
  ;print list "# exiting-and-infected = "  count passengers with [exit-time = ticks and infected? = true]

  print list "# entering = " count passengers with [enter-time = ticks]; count passengers with [new? = true]
  ;print list "# seated   = " count passengers with [shape = "person"]
  ;print list "# seated-and-infected   = " count passengers with [shape = "person" and infected? = true]

  ;print list "# total passengers = " count passengers

  ;print  "---"
  print  "   "

end

to exit-passengers

    ask passengers with [shape = "person"] [;in-seat? = true and
      if (ticks = exit-time) [
        set in-seat? false
        ;set color green
        set shape "person business"
        let cyan-patches (patches with [(pcolor = cyan - 2 or pcolor = cyan - 3) and (pxcor > -5 and pxcor <= 165)] ) ; or pcolor = cyan - 3
        move-to one-of cyan-patches with [not any? passengers in-radius 1] ;passengers-here
      die
    ]]

end

to enter-new-passengers

  ifelse ( ticks mod (average-travel-time + stop-time) = 0) and ticks != 0 and ticks != 720 [

    ;check how many empty seats available
    let num-empty-seats (count patches with [ pcolor = orange ] with [not any? passengers-here])

    ;randomize # of new passengers
    set new-passengers (random (num-empty-seats + 1))

    ;print list "--- time = " ticks
    ;print list "total (before) = " count passengers with [shape = "person"]
    ;print list "empty = " num-empty-seats
    ;print list "new   = " new-passengers

      create-passengers new-passengers [
        set infected? false
        set shape "person"
        set color blue - 2

        ;set stop-id after current ticks
        let current-stops floor (ticks / (average-travel-time + 2)) ;ceiling = round-up, floor = round-down
        set stop-id (current-stops + random (1 + simulation-length * 60 / average-travel-time - current-stops))
        set exit-time stop-id * average-travel-time + (2 * stop-id - 1)
        if exit-time >= 720 [set exit-time 720]
        set enter-time ticks

        ;inserting max-time-onboard
        if (exit-time - enter-time) > max-time-onboard [
          set stop-id (current-stops + random ( floor (max-time-onboard / (average-travel-time + 2)) ) ); + 1)
          set exit-time stop-id * average-travel-time + (2 * stop-id - 1) ]

        ;avoid exit-time is less than enter-time
        if exit-time < enter-time [
           set exit-time (stop-id + 1) * average-travel-time + (2 * (stop-id + 1) - 1)
        ]
        if exit-time >= 720 [set exit-time 720]
        set duration (exit-time - enter-time)
        set size 5.5
        set health 100
        set protected? true
        set in-seat? true
        set target-exit "exit 1"
        set new? true
        move-to one-of patches with [pcolor = orange and not any? passengers-here]
    ]
    ;print list "total = " count passengers with [shape = "person"]

  ][
    set new-passengers 0
  ]

end


;;; ;;;;;;;;;;;;;;;;;;;;;;;; ;;;
;;; functions called in "go" ;;;
;;; ;;;;;;;;;;;;;;;;;;;;;;;; ;;;

to spread-infection
  ask patches with [ p-infected? ] [
    ;; count down to the end of the patch infection
    set patch-infect-time patch-infect-time - 1
  ]

  ;set staff-members and corresponding patch to be INFECTED
  ask staff-members with [ infected? ] [
      ask staff-members-here [ set infected? true ]
      set p-infected? true
      set patch-infect-time disease-decay
  ]

  ;set passenger and corresponding patch to be INFECTED
  ask passengers with [ infected? ] [
      ask passengers-here [ set infected? true ]
      set p-infected? true
      set patch-infect-time disease-decay
  ]

   ;use spread probability
   let random100 (random-float 100) ;(random 100)
   ask passengers with [ color = red ][
    ifelse protected? = true
    [;part 1: spread to the protected group
      ask passengers in-radius 1 [
        if random100 < infection-probability  [
          if color = blue - 2 [ ;infect surrounding agent
             set infected? true
              ]]]]
    [;part 2: spread to the non-protected group
      ask passengers in-radius 1 [
        if random100 < (infection-probability * 2)  [
          ;if not-protected, then probability is twice as protected
          if color = blue - 2 [ ;infect surrounding agent
             set infected? true
              ]]]
    ]
   ]

  ;recording the passenger-infect-time
  ask passengers with [passenger-infect-time = 0 and infected? = true][
     set passenger-infect-time ticks
  ]

  ;recording the passenger-infect-time
  ask staff-members with [staff-infect-time = 0 and infected? = true][
     set staff-infect-time ticks
  ]

  ;infections from the stationary passengers
  ;ask passengers with [color = red and in-seat? = true and passenger-infect-time != 0 and (ticks - passenger-infect-time) > stationary-infection-period][
  ;  ask passengers in-radius 12 with [color = blue - 2 and (random-float 100) < infection-probability ] [ ;base case max seat distance = 12, incr capcity is less than it
  ;           set infected? true   ] ]


  ;infections from the virus movement
  ask passengers with [color = blue - 2] [
    if (any? viruses-here) and ((random-float 100) < infection-probability) [set infected? true]
  ]

  ;infections from the virus movement
  ask staff-members with [color = blue - 0] [
    if (any? viruses-here) and ((random-float 100) < infection-probability) [set infected? true]
  ]

  ;; the passengers that are on an infected patch become infected
  ask passengers with [ p-infected? and protected? = true and ((random-float 100) < infection-probability) ] [
      set infected? true   ]

  ask passengers with [ p-infected? and protected? = false and ((random-float 100) < (infection-probability * 2)) ] [
      set infected? true   ]

  ;set an infected patch to not-infected patch
  ask patches with [ p-infected? and patch-infect-time <= 0 ] [
    set p-infected? false  ]

end

to recolor
  ask passengers [ ; with [shape = "person" ]
    ;; infected turtles are red, others are blue - 2
    set color ifelse-value infected? [ red ] [ blue - 2 ]
  ]

  ask staff-members [
    ;; infected turtles are red, others are pink
    set color ifelse-value infected? [ red ] [ blue - 0 ]
  ]

  ;recolor infected/non patches...
  ask patches [
    ;; infected patches are yellow
    if (p-infected? = true) [
      ;set pcolor yellow
    ]

    ;; if not infected, set default color
    ;    if (p-infected? = false and pcolor = yellow) [
    ;       set pcolor [pcolor] of one-of neighbors
    ;
    ;    ]

    if (p-infected? = false and pcolor = yellow and count neighbors4 with [pcolor = gray + 2] >= 2)[ ;neighbors4 = 4 neighbors & neighbors = 8 neighbors
       set pcolor gray + 2
    ]

    if (p-infected? = false and pcolor = yellow and count neighbors4 with [pcolor = pink + 2] >= 2)[
       set pcolor pink + 2
    ]

    if (p-infected? = false and pcolor = yellow and count neighbors4 with [pcolor = blue - 2 + 2] >= 2)[
       set pcolor blue - 2 + 2
    ]
    if (p-infected? = false and pcolor = yellow and count neighbors4 with [ pcolor = orange ] >= 2)[
       set pcolor orange
    ]
    if (p-infected? = false and pcolor = yellow and count neighbors4 with [ pcolor = white  ] >= 2)[
       set pcolor white
    ]
    if (p-infected? = false and pcolor = yellow and count neighbors4 with [ pcolor = black  ] >= 2)[
       set pcolor black
    ]
    if (p-infected? = false and pcolor = yellow and count neighbors4 with [ pcolor = green  ] >= 2)[
       set pcolor green
    ] ]


end

to update-viruses
  ;update virus lifespan
  ask viruses [
    if (lifespan >= 1) [set lifespan (lifespan - 1)]
    if (lifespan  = 0) [die]
  ]

  ;new infected passengers have new viruses
  ask passengers with [passenger-infect-time != 0 and passenger-infect-time != 1 and passenger-infect-time = ticks ] [
    let x1 xcor
    let y1 ycor
    ;print (list passengers-here ticks " (" x1 ", " y1 ")")
    ask patches with [pxcor = x1 and pycor = y1] [
      sprout-viruses num-virus-per-passenger [
        set shape "circle 2"
        set color red + 1
        set lifespan virus-lifespan
        set random? false
        setxy (x1  - 5 + random 10) (y1 - 5 + random 10)
        set size 2.5
      ]
    ]
  ]

  ;new infected staffs have new viruses
  ask staff-members with [staff-infect-time != 0 and staff-infect-time != 1 and staff-infect-time = ticks ] [
    let x1 xcor
    let y1 ycor
    ;print (list passengers-here ticks " (" x1 ", " y1 ")")
    ask patches with [pxcor = x1 and pycor = y1] [
      sprout-viruses num-virus-per-passenger [
        set shape "circle 2"
        set color orange + 1
        set lifespan virus-lifespan
        set random? false
        setxy (x1  - 5 + random 10) (y1 - 5 + random 10)
        set size 2.5
      ]
    ]
  ]

  ;if a virus on door, window, or an outside patch, it dies
  ask patches with [pcolor = 104.7 or pcolor = 17.8 or pcolor = cyan - 1 or pcolor = cyan - 2 or pcolor = cyan - 3] [
    if any? viruses-here [ ask viruses-here [die] ]
  ]

end


to move-viruses

  ask viruses [

  ;general virus rule: face opposite direction when the front is wall ...
      if [pcolor] of patch-ahead 1 = black or [pcolor] of patch-ahead 2 =  black or [pcolor] of patch-ahead 1 = red or [pcolor] of patch-ahead 2 = red [
        forward -1 * virus-moving-speed
        right random 360 ]

  ;step 1: goes to bottom of the bus

    if random? = false [
      ;left
      if xcor <= 85 and ycor > 0 [
        facexy 6 ycor
        forward virus-moving-speed ]

      if xcor >= 5 and xcor <= 7[
        ;the upper half face middle first, then face the bottom
        ifelse ycor > 85 [facexy xcor 85][facexy xcor 1]
        forward virus-moving-speed ]

      ;right
      if xcor > 85 and ycor > 0 [
        facexy 155 ycor
        forward virus-moving-speed ]

      if xcor >= 154 and xcor <= 156[
        ;the upper half face middle first, then face the bottom
        ifelse ycor > 85 [facexy xcor 85][facexy xcor 1]
        forward virus-moving-speed ]
    ]

  ;step 2: random movement

    ;if a virus is at the bottom, set the state to -> random? true
    if (xcor = 5 or xcor = 6 or xcor = 7 or xcor = 154 or xcor = 155 or xcor = 156) and (ycor = 1 or ycor = 2 or ycor = 3)[
      set random? true
      ;forward -1 * virus-moving-speed
    ]

    if random? = true [
      ;facexy xcor 170 ; face the top first
      ;forward virus-moving-speed
        forward virus-moving-speed
        rt random 30
        lt random 30
    ]

  ];end of ask-viruses


end

to initial-infect
  ask n-of num-initial-infected passengers [
    set infected? true
    set p-infected? true
  ]
  ask passengers with [infected? = true][
      set passenger-infect-time 0
  ]
  ask staff-members with [infected? = true][
      set staff-infect-time 0
  ]
end


to set-geometry-layout-patches
  ask patches [

  ;bus boundary
  if (pxcor = 0 or pxcor = 160 and (pycor >= 0 and pycor <= 160) ) [set pcolor black]
  if (pycor = 0 or pycor = 160 and (pxcor >= 0 and pxcor <= 160) ) [set pcolor black]
  if (pxcor = 158 or pxcor = 159) and pycor = 131 [set pcolor black]

  ;outside environment
    if (pycor < 0 or pycor > 160) or (pxcor < 0 or pxcor > 160) [set pcolor cyan - 3] ;patch for exiters
    if (pycor >= -5 and pycor < 0) or (pycor > 160 and pycor <= 165) and (pxcor >= 0 and pxcor <= 160) [set pcolor cyan - 2] ;patch for enterers
    if (pxcor >= -5 and pxcor < 0) or (pxcor > 160 and pxcor <= 165) and (pycor >= -5 and pycor <=  165) [set pcolor cyan - 2] ;patch for enterers
    if (pxcor >= 161 and pxcor < 170) and (pycor > 131 and pycor <  155) [set pcolor cyan - 1] ;patch for enterers

  ;seats
    if pcolor > 110 and pcolor < 130
    [set pcolor cyan]

    if ( (pxcor >= 10 and pxcor <= 153) and (pycor >= 12 and pycor <= 124) ) and ( (pcolor >= 0 and pcolor < 5) or (pcolor > 5 and pcolor < 9.9) )
    [set pcolor cyan] ;pcolor != cyan or pcolor != grey or

    if   ( (pxcor >= 23 and pxcor <= 26) or (pxcor >= 54 and pxcor <= 57) or (pxcor >= 104 and pxcor <= 107) or (pxcor >= 135 and pxcor <= 138)  )
     and ( (pycor >= 15 and pycor <= 18) or (pycor >= 26 and pycor <= 29) or (pycor >= 38 and pycor <= 41) or (pycor >= 49 and pycor <= 52) or
           (pycor >= 62 and pycor <= 65) or (pycor >= 73 and pycor <= 76) or (pycor >= 85 and pycor <= 88) or (pycor >= 96 and pycor <= 99) or
           (pycor >= 108 and pycor <= 111) or (pycor >= 119 and pycor <= 122)   )
    [set pcolor cyan]

    if ( (pxcor = 55 or pxcor = 136) and (pycor = 73 or pycor = 96) )
    [set pcolor cyan]

  ;seats-cleaning
  if (pxcor = 58 or pxcor = 139) and pcolor = cyan
    [set pcolor white]

  ;if any? patches with [pcolor != cyan and (count neighbors4 with [pcolor = cyan] >= 2)]
  ;  [set pcolor cyan]

  ;seat boundaries
    if ( (pxcor >= 10 and pxcor <= 72) or (pxcor >= 90 and pxcor <= 153) ) and (pycor = 124 or pycor = 117 or pycor = 113 or pycor = 106 or pycor = 101 or pycor = 94  or pycor = 90 or pycor = 83 or pycor = 78 or pycor = 71 or pycor = 67 or pycor = 60 or pycor = 54 or pycor = 47 or pycor = 43 or pycor = 36 or pycor = 31 or pycor = 24 or pycor = 20 or pycor = 13)
    [set pcolor grey]

    if ( (pycor >= 13 and pycor <= 20) or (pycor >= 24 and pycor <= 31) or (pycor >= 36 and pycor <= 43) or (pycor >= 47 and pycor <= 54) or (pycor >= 60 and pycor <= 67) or (pycor >= 71 and pycor <= 78) or (pycor >= 83 and pycor <= 90) or(pycor >= 94 and pycor <= 101) or (pycor >= 106 and pycor <= 113) or (pycor >= 117 and pycor <= 124) ) and (pxcor = 10 or pxcor = 41 or pxcor = 72 or pxcor = 90 or pxcor = 122 or pxcor = 153)
     [set pcolor grey]

  ;driver seat
    if (pxcor >= 36 and pxcor <= 46) and (pycor >= 137 and pycor <= 145)
    [set pcolor 22.5]

  ;driver seat cleaning
  if pxcor = 41 and pycor = 146
    [set pcolor white]

  ;driver seat center
  if pxcor = 41 and pycor = 141
    [set pcolor orange + 3]

  ;driver seat boundaries
    if (pxcor >= 10 and pxcor <= 74) and (pycor = 131 or pycor = 152)
      [set pcolor (grey + 1) ]
    if (pxcor = 10 or pxcor = 74) and (pycor >= 131 and pycor <= 152)
      [set pcolor (grey + 1) ]

  ;passenger seat centers - pcolor = orange
   if ( (pxcor = 24 or pxcor = 55 or pxcor = 105 or pxcor = 136)  and
        (pycor = 17 or pycor = 28 or pycor = 40 or pycor = 51 or pycor = 64 or pycor = 75 or pycor = 87 or pycor = 98 or pycor = 110 or pycor = 121 ) )
    [set pcolor orange]

  ;windows
    if ( (pxcor >= 0 and pxcor <= 2) or (pxcor >= 158 and pxcor <= 160) ) and ( (pycor >= 11 and pycor <= 21) or (pycor >= 23 and pycor <= 32) or (pycor >= 34 and pycor <= 44) or (pycor >= 46 and pycor <= 56) or (pycor >= 58 and pycor <= 68) or (pycor >= 70 and pycor <= 80) or (pycor >= 82 and pycor <= 91) or (pycor >= 93 and pycor <= 103) or (pycor >= 105 and pycor <= 114) or (pycor >= 116 and pycor <= 126) )
    [set pcolor 17.8] ;initial patch color is 17.8

    if ( (pxcor >= 0 and pxcor <= 2) or (pxcor >= 158 and pxcor <= 160) ) and (pycor >= 10 and pycor <= 127) and (pcolor != 17.8)
    [set pcolor black]

    if ( (pxcor >= 158 and pxcor <= 160) ) and pycor = 45
    [set pcolor black]

  ;cleaning front and end of bus
   if (pxcor >= 17 and pxcor <= 144) and ( (pycor >= 1 and pycor <= 5) or (pycor >= 155 and pycor <= 159) ) and (pcolor != white)
    [set pcolor white]

  ;doors
    if ( (pxcor >= 158 and pxcor <= 160) ) and ( (pycor >= 132 and pycor <= 154)  )
      [set pcolor 104.7]
    if ( (pxcor >= 158 and pxcor <= 160) ) and pycor = 155
      [set pcolor black]

  ;emergency-door (bottom)
    if ( (pxcor >= 68 and pxcor <= 92) ) and ( (pycor >= 0 and pycor <= 2)  )
      [set pcolor 104.7]
    if ( (pxcor = 67 or pxcor = 93) ) and (pycor >= 0 and pycor <= 2)
      [set pcolor black]

  ;

  ;RHS exit and entrance patches
  ;if pxcor > 160 and pxcor < 165
  ;[set pcolor cyan]

    ;below code applies when there's a capacity limit (capacity less than 100)
    ;50% capacity
    if seat-capacity = 50 [
      if (pxcor = 24 or pxcor = 105) and (pycor = 17 or pycor = 40 or pycor = 64 or pycor = 87 or pycor = 110 ) [set pcolor yellow]
      if (pxcor = 55 or pxcor = 136) and (pycor = 28 or pycor = 51 or pycor = 75 or pycor = 98 or pycor = 121 ) [set pcolor yellow]
    ]

    ;25% capacity
    if seat-capacity = 25 [
      if (pxcor = 55 or pxcor = 105 or pxcor = 136) and (pycor =  17) [set pcolor yellow]
      if (pxcor = 24 or pxcor = 105 or pxcor = 136) and (pycor =  28) [set pcolor yellow]
      if (pxcor = 24 or  pxcor = 55 or pxcor = 136) and (pycor =  40) [set pcolor yellow]
      if (pxcor = 24 or  pxcor = 55 or pxcor = 105) and (pycor =  51) [set pcolor yellow]
      if (pxcor = 55 or pxcor = 105 or pxcor = 136) and (pycor =  64) [set pcolor yellow]
      if (pxcor = 24 or pxcor = 105 or pxcor = 136) and (pycor =  75) [set pcolor yellow]
      if (pxcor = 24 or  pxcor = 55 or pxcor = 136) and (pycor =  87) [set pcolor yellow]
      if (pxcor = 24 or  pxcor = 55 or pxcor = 105) and (pycor =  98) [set pcolor yellow]
      if (pxcor = 55 or pxcor = 105 or pxcor = 136) and (pycor = 110) [set pcolor yellow]
      if (pxcor = 24 or pxcor = 105 or pxcor = 136) and (pycor = 121) [set pcolor yellow]
    ]

  ]

end




to others

  set-default-shape viruses "circle 2"

  let num-viruses (count passengers with [infected?]) * 4
  create-viruses num-viruses [
    set lifespan virus-lifespan

    ;; assign a virus to each sick passenger
    let one-sick-passenger (one-of passengers with [ infected? = true])

    ;; set virus' coordinates around the infected people
    setxy ([xcor] of one-sick-passenger - 5 + random 10) ([ycor] of one-sick-passenger - 5 + random 10)

    set size 2.5

  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
97
11
829
744
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-10
170
-10
170
0
0
1
ticks
30.0

BUTTON
16
24
82
57
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
18
70
81
103
NIL
go
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
18
112
81
145
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
1

SLIDER
839
227
1016
260
simulation-length
simulation-length
0
24
12.0
4
1
hour
HORIZONTAL

SLIDER
838
55
1014
88
infection-probability
infection-probability
0
100
100.0
5
1
%
HORIZONTAL

SWITCH
1036
143
1211
176
close-all-windows?
close-all-windows?
0
1
-1000

SWITCH
1036
182
1213
215
close-all-doors?
close-all-doors?
0
1
-1000

SLIDER
1037
55
1210
88
num-staff-members
num-staff-members
0
1
1.0
1
1
NIL
HORIZONTAL

SLIDER
1036
96
1210
129
num-virus-per-passenger
num-virus-per-passenger
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
1036
269
1213
302
virus-lifespan
virus-lifespan
0
1000
1000.0
5
1
min
HORIZONTAL

SLIDER
839
96
1014
129
window-open
window-open
0
100
0.0
5
1
%
HORIZONTAL

SLIDER
1036
311
1213
344
disease-decay
disease-decay
0
100
12.0
1
1
min
HORIZONTAL

SLIDER
839
270
1017
303
social-distance
social-distance
0
6
6.0
6
1
ft
HORIZONTAL

SLIDER
839
139
1014
172
average-travel-time
average-travel-time
5
30
20.0
5
1
min
HORIZONTAL

SLIDER
1036
226
1213
259
virus-moving-speed
virus-moving-speed
0.25
1
1.0
0.25
1
patch
HORIZONTAL

SLIDER
839
313
1016
346
seat-capacity
seat-capacity
50
100
100.0
50
1
%
HORIZONTAL

TEXTBOX
848
21
998
39
Scenario Parameters:\n
13
0.0
1

TEXTBOX
1038
20
1188
38
Other Parameters:
13
0.0
1

SLIDER
840
182
1015
215
stop-time
stop-time
1
2
2.0
1
1
min
HORIZONTAL

SLIDER
839
354
1019
387
max-time-onboard
max-time-onboard
30
120
60.0
30
1
min
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

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

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person construction
false
0
Rectangle -7500403 true true 123 76 176 95
Polygon -1 true false 105 90 60 195 90 210 115 162 184 163 210 210 240 195 195 90
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Circle -7500403 true true 110 5 80
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -955883 true false 180 90 195 90 195 165 195 195 150 195 150 120 180 90
Polygon -955883 true false 120 90 105 90 105 165 105 195 150 195 150 120 120 90
Rectangle -16777216 true false 135 114 150 120
Rectangle -16777216 true false 135 144 150 150
Rectangle -16777216 true false 135 174 150 180
Polygon -955883 true false 105 42 111 16 128 2 149 0 178 6 190 18 192 28 220 29 216 34 201 39 167 35
Polygon -6459832 true false 54 253 54 238 219 73 227 78
Polygon -16777216 true false 15 285 15 255 30 225 45 225 75 255 75 270 45 285

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

person graduate
false
0
Circle -16777216 false false 39 183 20
Polygon -1 true false 50 203 85 213 118 227 119 207 89 204 52 185
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -8630108 true false 90 19 150 37 210 19 195 4 105 4
Polygon -8630108 true false 120 90 105 90 60 195 90 210 120 165 90 285 105 300 195 300 210 285 180 165 210 210 240 195 195 90
Polygon -1184463 true false 135 90 120 90 150 135 180 90 165 90 150 105
Line -2674135 false 195 90 150 135
Line -2674135 false 105 90 150 135
Polygon -1 true false 135 90 150 105 165 90
Circle -1 true false 104 205 20
Circle -1 true false 41 184 20
Circle -16777216 false false 106 206 18
Line -2674135 false 208 22 208 57

person lumberjack
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -2674135 true false 60 196 90 211 114 155 120 196 180 196 187 158 210 211 240 196 195 91 165 91 150 106 150 135 135 91 105 91
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -6459832 true false 174 90 181 90 180 195 165 195
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -6459832 true false 126 90 119 90 120 195 135 195
Rectangle -6459832 true false 45 180 255 195
Polygon -16777216 true false 255 165 255 195 240 225 255 240 285 240 300 225 285 195 285 165
Line -16777216 false 135 165 165 165
Line -16777216 false 135 135 165 135
Line -16777216 false 90 135 120 135
Line -16777216 false 105 120 120 120
Line -16777216 false 180 120 195 120
Line -16777216 false 180 135 210 135
Line -16777216 false 90 150 105 165
Line -16777216 false 225 165 210 180
Line -16777216 false 75 165 90 180
Line -16777216 false 210 150 195 165
Line -16777216 false 180 105 210 180
Line -16777216 false 120 105 90 180
Line -16777216 false 150 135 150 165
Polygon -2674135 true false 100 30 104 44 189 24 185 10 173 10 166 1 138 -1 111 3 109 28

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

person service
false
0
Polygon -7500403 true true 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -1 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -1 true false 123 90 149 141 177 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -16777216 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="HF-Base" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HF-1" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HF-2" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-Base" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-1" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-2" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-3" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HF-Base_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HF-1_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HF-2_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-Base_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-1_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-2_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LF-3_10v" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count passengers with [exit-time = ticks]</metric>
    <metric>count passengers with [exit-time = ticks and infected? = true]</metric>
    <metric>new-passengers</metric>
    <metric>count passengers with [shape = "person"]</metric>
    <metric>count passengers with [shape = "person" and infected? = true]</metric>
    <enumeratedValueSet variable="close-all-windows?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-virus-per-passenger">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-staff-members">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="window-open">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seat-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-travel-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="protected-population">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-sim-details?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-lifespan">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disease-decay">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stationary-infection-period">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="passenger-moving-speed">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-length">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="close-all-doors?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-moving-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-time-onboard">
      <value value="60"/>
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
