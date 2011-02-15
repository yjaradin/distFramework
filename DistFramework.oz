functor
import
   LKDictionary(new:NewLKDic)
   SerializationUtils(toAlpha:ToAlpha
		      fromAlpha:FromAlpha)
   Internals
export
   Session
   LayerManager
   process:ProcessLayer
   pp2p:PP2PLayer
   Version
define
   Version=2
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
	    proc{This M} {Send P M} end
	    this:=This
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
		  {self {Adjoin M S.L}}
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



   /*
   fun{PP2PLayer LM ?Uri}
      SP2P={LM getLayer('dist-layer:sp2p' $)}
      PP2PId='07f23ac1-9fe1-4f96-a7d3-a8212bb368fc' %Anything unique enough
   in
      Uri='dist-layer:pp2p'
      class from Session
	 attr h sp2p messages
	 meth init(SId Handler)
	    h:=Handler
	    sp2p:={SP2P init(PP2PId|SId {self facet(sp2pdeliver:SDeliver $)})}
	    messages:=nil
	 end
	 meth pp2pSend(Dest Msg)
	    {@sp2p sp2pSend(Dest m({NewName} Msg))}
	 end
	 meth SDeliver(Src SMsg)
	    m(Id Msg)=SMsg in
	    if {Not{Member Id @messages}} then
	       messages:=Id|@messages
	       {@h pp2pDeliver(Src Msg)}
	    end
	 end
      end
   end
   */
end