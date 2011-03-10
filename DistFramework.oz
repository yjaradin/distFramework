functor
import
   LKDictionary(new:NewLKDic)
   SerializationUtils(toAlpha:ToAlpha
		      fromAlpha:FromAlpha)
   Internals
   Property
export
   Session
   LayerManager
   process:ProcessLayer
   pp2p:PP2PLayer
   alarm:AlarmLayer
   Version
define
   Version=3
   local
      InternalLayers=i(port:Internals.internalLayerPort
		       socket:Internals.internalLayerSocket)
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
	    {self introduceLayer(InternalLayers.Kind)}
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

   fun{ProcessLayer LM ?Uri}
      Internals={{LM getLayer('dist-base:internals' $)} init()}
   in
      Uri='dist-layer:process'
      class from Session
	 meth init()
	    skip
	 end
	 meth here($)
	    {Internals thisDest($)}
	 end
	 meth toText(D $)
	    {ToAlpha {Internals serializeDest(D $)} ""}
	 end
	 meth fromText(A $)
	    {Internals deserializeDest({FromAlpha A nil}$)}
	 end
      end
   end
   
   fun{PP2PLayer LM ?Uri}
      Internals={{LM getLayer('dist-base:internals' $)} init()}
      UUID='pp2p:cbdafcff-b57a-43d6-aa00-8fcc60a298d2'
      Sessions={NewLKDic}
      proc{DontCare Src M}skip end   
      thread
	 for iMsg(Src Msg) in {Internals receive($)} do
	    case Msg of UUID(Id M) then
	       {{Sessions condGet(Id DontCare $)} pp2pDeliver(Src M)}
	    else skip
	    end
	 end
      end
   in
      Uri='dist-layer:pp2p'
      class from Session
	 attr sid
	 meth init(SId Handler)
	    sid:=SId
	    {Sessions put(@sid Handler)}
	 end
	 meth pp2pSend(Dest M)
	    {Internals send(Dest UUID(@sid M))}
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