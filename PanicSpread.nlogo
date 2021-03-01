;;日总
globals [
  M
  N
  N_new
  increase      ;;increase，判断病例总数是否增加
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
  set M 0           ;;全局媒体强度
  set N 0           ;;上一天感染人数
  set N_new 0       ;;上一天新增感染人
  set increase false
  set add-infection 0
  set cure 0
  set test-probability 0
  set day 0
  set contact 20
  ask turtles[
    become-susceptible
  ]

  ask turtles [               ;;循环
  set Y random-normal 0 0.1
  set susceptible true
  set exposed false
  set infection false
  set recover false

  ]
  ask n-of initial-outbreak-size turtles
    [ become-exposed ]  ;; 初始化指定数量的暴露者

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
  if all? turtles [(not infection) and (not exposed)] ;; 如果全部的状态为未被感染，那就停止运行
    [ stop ]
  panic-media
  ask turtles
  [
    update-panic
    set virus-check-timer 0
  ]
  ask turtles
  [
     set virus-check-timer virus-check-timer + 1                      ;;每次go，都给 “距离上一次病毒检查过去了多少时间步” 记一次时
     if (virus-check-timer >= virus-check-frequency and susceptible)  ;; 定期做检查
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

  let Ni count turtles with [infection] + test-probability * count turtles with[exposed] - N            ;;记录本轮感染人数

   ifelse Ni >  N_new
  [                                    ;;判断确诊人数是否大
    set increase true
  ]
  [set increase false]
  set N_new Ni
  set N count turtles with [infection] + test-probability * count turtles with[exposed]



   ;; 调用函数，实现暴露者和感染者康复
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

to update-panic                         ;;更新个人信息恐慌情绪


   ifelse infection
  [
    panic-infection    ;;感染后恐慌情绪变化-Y
  ]

  [
    panic-neighbors    ;;从邻居处获得的恐慌情绪
    if random-float 1 < get-media-rate and not infection          ;;以概率k从媒体获得恐慌,修正自身恐慌情绪
    [
      let degree count link-neighbors
      let x (Y * degree + M) / degree
      set Y (e ^ x - e ^ ( -1 * x)) / (e ^ x + e ^ ( -1 * x))                 ;;朋友越多，全局媒体强度影响约小
    ]
  ]


  panic-reduce         ;;恐慌度自然衰减比率


end




to become-susceptible  ;; 个体变成易感的
  set susceptible true
  set exposed false
  set infection false
  set recover false
  set color blue
end

to become-exposed  ;; 个体转为暴露者
  set susceptible false
  set exposed true
  set infection false
  set recover false
  set color yellow
end

to become-infection  ;; 个体被感染
  set susceptible false
  set exposed false
  set infection true
  set recover false
  set color red
end



to become-recover  ;; 个体被获得病毒抗性
  set susceptible true
  set exposed false
  set infection false
  set recover true
  set color gray
  ask my-links [ set color gray - 2 ] ;; 让无效节点的连边颜色变灰
end



to panic-infection                       ;;感染后恐慌情绪变化
  set Y random-float 0.1 + k
end

to panic-neighbors                    ;;从邻居处获得的恐慌情绪
  let Y-neighbor 0                                             ;;计算公式分子
  let high-num-neighbors count link-neighbors with [Y > 0.6]   ;;计算高权重邻居所占权重
  let low-num-neighbors count link-neighbors with [Y <= 0.6]   ;;计算低权重邻居所占权重
  let wight-neighbors high-num-neighbors * 10 + low-num-neighbors
  ask link-neighbors
  [
    ifelse Y > 0.6 [set Y-neighbor Y-neighbor + Y * 10 ]
                   [set Y-neighbor Y-neighbor + Y ]
  ]
  set Y Y-neighbor / wight-neighbors
end

to panic-media                          ;;全局媒体强度

    ifelse increase
  [
    ifelse (count turtles with [infection] + test-probability * count turtles with[exposed]) < 100
    [set M k / 5]
    [set M k / 2]
  ]       ;;如果病例数增加时全局媒体强度变化
  [set M 0]
end



to panic-reduce                          ;;恐慌度自然衰减比率
  set Y panic-reduce-rate * Y
end

to spread-virus ;; 健康人感染病毒
  let people count turtles
  let exposed_count count turtles with [exposed]
  let infection_count count turtles with [infection]
  let rate ((contact * exposed_infected * exposed_count + contact * infection_infected * infection_count) / people) ;;可优化减少运算复杂度
  let real_rate rate * (count turtles with [susceptible]) / people
  set signal1 real_rate
  ask turtles with [ susceptible and not recover ]
    [if random-float 100 < real_rate
      [become-exposed]]

    ;;[ ask turtles with [not recover]
    ;;    [ if random-float 100 < virus-spread-chance
    ;;        [ become-infection ] ] ]
end

to convert-infection  ;;一定天数由暴露者转化为染病者
  ask turtles with[exposed]
  [
    if random-normal -2 2 + incubation < virus-check-timer      ;;使用随机数使得患病更均匀
      [become-infection]
  ]


end



to do-virus-checks  ;; 暴露者和感染者康复
  ask turtles with [(infection or exposed) and virus-check-timer > 0]
  [
    if random 100 < recovery-chance  ;; 有一定概率治愈或自愈
    [
        become-recover
      ;;ifelse random 100 < gain-resistance-chance
      ;;  [ become-recover ]    ;;在治愈的基础上，有一定概率能获得病毒抗性
      ;;  [ become-susceptible ]  ;;不够幸运，未能获得病毒抗性的人，重新变成易感的
    ]
  ]
end
