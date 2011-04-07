functor
import
   LKDictionary(new:NewLKDic)
   Property
   Comm
   Dist
export
   Session
   LayerManager
   Version
define
   Version=4
   local
      SessionInit={NewName}
      PreInit={NewName}
   in
      class LayerManagerClass
	 attr
	    layers
	 meth !PreInit()
	    layers:=nonInitialized
	 end
	 meth init(Kind<=port)
	    layers:={Dictionary.new}
	    {self introduceLayer(AlarmLayer)}
	    for F in [remoteProcess router localProcess] do
	       {self introduceLayer(Comm.F)}
	    end
	    for F in [comm process bep2p pp2p ifd pfd] do
	       {self introduceLayer(Dist.F)}
	    end
	 end
	 meth introduceLayer(LayerFunc)
	    LayerUri
	    LayerClass={LayerFunc self LayerUri}
	 in
	    fun{{self getLayer(LayerUri $)} UserInit}
	       {New LayerClass SessionInit(UserInit $) _}
	    end
	 end
	 meth getLayer(Uri ?N)
	    {Dictionary.condExchange @layers Uri _ N N}
	 end
      end
      LayerManager={New LayerManagerClass PreInit()}
      class Session
	 attr this
	 meth !SessionInit(UserInit ?This)
	    P in
	    proc{This M} {@this M} end
	    this:=proc{$ M} {Send P M} end
	    P={NewPort thread
			  {self UserInit}
			  for M in $ do
			     {self M}
			  end
		       end}
	 end
	 meth facet($ ...)=S
	    proc{$ M}
	       L={Label M} in
	       if {HasFeature S L} then
		  {@this {Adjoin M S.L}}
	       end
	    end
	 end
      end
   end
   fun{AlarmLayer LM ?Uri}
      Alarms={NewCell nil}
      Sessions={NewLKDic}
      proc{Tick}
	 ToDo Now OAl NAl
      in
	 OAl=Alarms:=NAl
	 {Wait OAl}
	 Now={Property.get 'time.total'}
	 NAl={List.takeDropWhile OAl fun{$ T#_#_}T<Now end ToDo $}
	 for _#S#P in ToDo do
	    {{Sessions get(S $)} alarm(P)}
	 end
	 if NAl\=nil then
	    {Delay {Max 0 Now-NAl.1.1}}
	    {Tick}
	 end
      end
   in
      Uri='dist-layer:alarm'
      class from Session
	 attr sid
	 meth init(SId Handler)
	    sid:=SId
	    {Sessions put(@sid Handler)}
	 end
	 meth getTime($)
	    {Property.get 'time.total'}
	 end
	 meth setAlarmAt(Time Payload)
	    OAl NAl in
	    OAl=Alarms:=NAl
	    NAl={List.merge OAl [Time#@sid#Payload] fun{$ X#_#_ Y#_#_}X<Y end}
	    if OAl==nil orelse OAl.1.1 > Time then
	       thread
		  {Delay {Max 0 Time-{self getTime($)}}}
		  {Tick}
	       end
	    end
	 end
	 meth setAlarmIn(Interval Payload)
	    {self setAlarmAt({self getTime($)}+Interval Payload)}
	 end
      end
   end
end