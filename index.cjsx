{relative, join} = require 'path-extra'
fs = require 'fs-extra'
{_, $, $$, React, ReactBootstrap, ROOT, resolveTime, layout, toggleModal} = window
{Table, ProgressBar, Grid, Input, Col, Alert} = ReactBootstrap
{APPDATA_PATH, SERVER_HOSTNAME} = window

ss_dat = require join(__dirname,'assets','ss_dat.json')
Shiprow = require './shiprow'

EXP99 = 1000000
EXPMAX = 5470000

ss = (id) ->
  ss_dat.ss_mapping[id]

getHPcondition = (percent) ->
  if percent <= 25
    4
  else if percent <= 50
    3
  else if percent <= 75
    2
  else if percent < 100
    1
  else 0
HPcondition = ['nondamaged', 'slightlydamaged', 'litedamaged', 'middamaged', 'heavydamaged']

module.exports =
  name: 'sukumizu-helper'
  priority: 8
  displayName: <span><FontAwesome key={0} name='anchor' />{' ' + "Sukumizu Helper"}</span>
  description: "Choose submerine automatically"
  version: '1.0.0'
  author: 'RPMAN'
  link: 'https://github.com/cmrpman'
  reactClass: React.createClass
    getInitialState: ->
      ss_queue: []
      HPcondition_avail: 0
      cond_avail: 43
      lv_avail: 20
      is_show_maruyu: false
      unix_timestamp: Date.now()
    data:
      cond_time_logger: {}
      cond_fetch_time: Date.now()
    flush: (ndocks) ->
      ss_queue = []
      ss_in_ndock = {}
      for ndock in ndocks
        kn_id = ndock.api_ship_id
        continue if kn_id == 0
        ship_id = _ships[kn_id].api_ship_id
        ssid = ss(ship_id)
        continue unless ssid
        ss_in_ndock[kn_id] = ndock.api_complete_time
      for kn_id, ship of _ships
        ship_id = ship.api_ship_id
        ssid = ss(ship_id)
        continue unless ssid
        ss_queue.push
          kn_id: kn_id
          ssid: ssid
          name: ship.api_name
          exp: ship.api_exp[0]
          cond: ship.api_cond
          ndock_finish_time: (if ss_in_ndock[kn_id]? then ss_in_ndock[kn_id] else -1)
          nowhp: ship.api_nowhp
          maxhp: ship.api_maxhp
          HPcond: getHPcondition(ship.api_nowhp * 100 / ship.api_maxhp)
          lv: ship.api_lv
          ndock_time: ship.api_ndock_time
        @data.cond_fetch_time = Date.now()
      @setState
        ss_queue: ss_queue
    flush_timer: () ->
      @setState
        unix_timestamp: Date.now()
    handleResponse: (e) ->
      {method, path, body, postBody} = e.detail
      switch path
        when '/kcsapi/api_port/port'
          @flush body.api_ndock
        when '/kcsapi/api_get_member/ndock'
          @flush body
    componentDidMount: ->
      window.addEventListener 'game.response', @handleResponse
      @interval = setInterval(@flush_timer, 1000);
    componentWillUnmount: ->
      window.removeEventListener 'game.response', @handleResponse
      clearInterval @interval
    render: ->
      <div>
      <link rel="stylesheet" href={join(relative(ROOT, __dirname), 'assets', 'sukumizu-helper.css')} />
      {    
        ss_sign = {}
        ss_queue = []
        ss_recommand_queue = []
        ss_pending_queue = []
        ss_repair_queue = []
        ss_avail_queue = []
        ss_wait_queue = []
        curtime = @state.unix_timestamp
        for ship in @state.ss_queue
          if(ship.ssid != ss_dat.maruyu_mapedid || @state.is_show_maruyu)
            ship.sort_exp = ship.exp
            ss_queue.push ship
        #set ss with highest exp to expmax
        ss_queue.sort((a,b) ->
          a.exp - b.exp
        )
        ss_queue[ss_queue.length-1].sort_exp = EXPMAX if ss_queue.length - 1 >= 0
        #set ss with lv99 to expmax - 1
        for ship in ss_queue
          ship.sort_exp = EXPMAX - 1 if ship.sort_exp == EXP99
        #sort using adjusted exp
        ss_queue.sort((a,b) ->
          a.sort_exp - b.sort_exp
        )
        for dat,i in ss_queue
          cont_flag = false
          dat.wait_type = undefined
          dat.wait_finish_time = undefined
          #loss HP
          if dat.HPcond > @state.HPcondition_avail
            #need repair but not repaired
            if dat.ndock_finish_time < 0             
              dat.wait_finish_time = dat.ndock_time + curtime
              dat.wait_type = 'need repair'
              dat.repair_finish_time = dat.ndock_time + curtime
              ss_repair_queue.push dat
            #repairing
            else
              dat.wait_finish_time = dat.ndock_finish_time
              dat.wait_type = 'repairing'
              dat.repair_finish_time = dat.ndock_finish_time
            ss_pending_queue.push dat
            cont_flag = true
          #fatigue
          if dat.cond < @state.cond_avail
            ss_pending_queue.push dat unless dat.wait_finish_time
            #eval cond time?
            tmp_cond_time = @data.cond_fetch_time + 180000 * Math.ceil((@state.cond_avail - dat.cond) / 3)
            if !@data.cond_time_logger[dat.kn_id] || Math.abs(tmp_cond_time - @data.cond_time_logger[dat.kn_id]) >= 180000
               @data.cond_time_logger[dat.kn_id] = tmp_cond_time
            else @data.cond_time_logger[dat.kn_id] = Math.min(tmp_cond_time, @data.cond_time_logger[dat.kn_id])
            #use logged cond time if longer than repair
            if !dat.wait_finish_time || dat.wait_finish_time < @data.cond_time_logger[dat.kn_id]
              dat.wait_finish_time = @data.cond_time_logger[dat.kn_id]
            #edit type
            if dat.wait_type
              dat.wait_type += ' fatigue'
            else dat.wait_type = 'fatigue'
            cont_flag = true
          #not fatigue
          else @data.cond_time_logger[dat.kn_id] = undefined
          #rank unmatch    
          if dat.lv < @state.lv_avail
            cont_flag = true
          continue if cont_flag
          #available
          ss_recommand_queue.push dat
        [
          <h5 className="title">Recommand</h5>
          <ul>
          {
            for dat,i in ss_recommand_queue
              if ss_sign[dat.ssid]
                ss_avail_queue.push dat
                continue
              ss_sign[dat.ssid] = true;
              <Shiprow
                key={"recomms"+i}
                thename={"recomm"}
                seq={i}
                dat={dat}
                curtime={curtime}
                showtype={false}
                showtime={false}
                HPcondition={HPcondition}
              />
          }
          </ul>
          <h5 className="title">Pending</h5>
          <ul>
          {
            ss_pending_queue.sort((a,b) ->
              a.wait_finish_time - b.wait_finish_time
            )
            for dat,i in ss_pending_queue
              if ss_sign[dat.ssid]
                ss_wait_queue.push dat
                continue
              ss_sign[dat.ssid] = true;
              <Shiprow
                key={"pends"+i}
                thename={"pend"}
                seq={i}
                dat={dat}
                curtime={curtime}
                showtype={true}
                showtime={true}
                HPcondition={HPcondition}
              />
          }
          </ul>
          <h5 className="title">Need Repair</h5>
          <ul>
          {
            #recommand the ship that could be available faster (not only repairing, concerning fatigue)
            ss_repair_queue.sort((a,b) ->
              a.wait_finish_time - b.wait_finish_time
            )
            for dat,i in ss_repair_queue
              <Shiprow
                key={"repairs"+i}
                thename={"repair"}
                seq={i}
                dat={dat}
                curtime={curtime}
                showtype={true}
                showtime={true}
                HPcondition={HPcondition}
              />
          }
          </ul>
          <h5 className="title">Available</h5>
          <ul>
          {
            for dat,i in ss_avail_queue
              <Shiprow
                key={"avails"+i}
                thename={"avail"}
                seq={i}
                dat={dat}
                curtime={curtime}
                showtype={false}
                showtime={false}
                HPcondition={HPcondition}
              />
          }
          </ul>
          <h5 className="title">Waiting</h5>
          <ul>
          {
            for dat,i in ss_wait_queue
              <Shiprow
                key={"waits"+i}
                thename={"wait"}
                seq={i}
                dat={dat}
                curtime={curtime}
                showtype={true}
                showtime={true}
                HPcondition={HPcondition}
              />
          }              
          </ul>
        ]
      }
      </div>
