{React} = window

#name
#seq
#dat
#curtime
#showtype
#showtime

us2dstr = (date) ->
  new Date(date).toLocaleTimeString()
ms2tstr = (ms) ->
  ss = Math.floor(ms / 1000)
  rs = ss % 60
  rm = Math.floor(ss / 60) % 60
  rh = Math.floor(ss / 3600)
  res = rh+':'+rm+':'+rs
  
Shiprow = React.createClass
  render: ->
    <div>
      <li className="ss_annotated">{
        res = ''
        for k,v of @props.dat
          res += k+':'+v+' '
        res
      }</li>    
      <li>{
        if @props.showtype
          <span className="ss_type">{@props.dat.wait_type} </span>
      }
        <span className="ss_lv_t">Lv. </span>
        <span className="ss_lv">{@props.dat.lv} </span>
        <span className="ss_name">{@props.dat.name} </span>
        <span className="ss_cond_t">Cond. </span>
        <span className="ss_cond">{@props.dat.cond} </span>
        <span className="ss_hpc">{@props.HPcondition[@props.dat.HPcond]} </span>
      {
        if(@props.showtime)
          [
            <span className="ss_wtt">Finish in:</span>
            <span className="ss_wtt">{ms2tstr(Math.max(@props.dat.wait_finish_time - @props.curtime,0))} </span>
            <span className="ss_wftt">By:</span>
            <span className="ss_wait_finish_time">{us2dstr(@props.dat.wait_finish_time)}</span>
          ]
      }</li>
	  </div>

module.exports = Shiprow