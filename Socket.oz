functor
import
   DistFramework(session:Session)
   Open
   OS
   Pickle(pack:Pack unpack:Unpack)
   SerializationUtils(toAlpha:ToAlpha
		      completeTokens:CompleteTokens)
export
   ClientIP
   ProviderIP
define
class SocketConnection
   attr
      s p d
   meth init(S Here)
      Msgs in
      s:=S
      d:=_
      {Wait Here}
      {@s write(vs:{ToAlpha {Pack Here} ","})}
      Msgs=
      thread
	 {Map
	  thread S in
	     thread
		try
		   {@s read(list:S size:all)}
		catch _ then
		    {self close()}
		end
	     end
	      {CompleteTokens S ","}
	  end Unpack}
      end
      p:=Msgs.1
      thread
	 for m(From To Msg) in Msgs.2 do
	    {@d deliver(From To Msg)}
	 end
      end
   end
   meth reg(DeliverFacet)
      @d=DeliverFacet
   end
   meth send(From To Msg)
      try
	 {@s write(vs:{ToAlpha {Pack m(From To Msg)} ","})}
      catch _ then
	 {self close()}
      end
   end
   meth getProcess($)
      @p
   end
   meth close()
      try
	 {@s close()}
	 if {IsDet @d} then
	    {@d connection(remove self)}
	 end
      catch _ then
	 skip
      end
   end
end

fun{ProviderIP LM ?Uri}
   Process={{LM getLayer('dist-layer:process' $)} init()}
in
   Uri='address-provider:IPSocket'
   class from Session
      attr
	 p
	 s
      meth init(Sync<=_)
	 PortNr Address in
	 s:={New Open.socket init()}
	 {@s bind(port:PortNr)}
	 {@s listen}
	 Address=a(layer:'address-client:IPSocket'
		   hosts:{OS.uName}.nodename|
		   {Append
		    {OS.getHostByName {OS.uName}.nodename}.addrList
		    {OS.getHostByName "localhost"}.addrList
		   }
		   port:PortNr)
	 thread
	    proc{Loop}
	       try
		  Sync
		  S={@s accept(acceptClass:Open.socket accepted:$)} in
		  {Process connection(add {New SocketConnection init(S {Process here($)})} Sync)}
		  {Wait Sync}
	       catch _ then %e.g. Too many open connections
		  {Delay 100}
	       end
	       {Loop}
	    end
	 in
	    {Loop}
	 end
	 {Process address(add Address Sync)}
      end
   end
end

fun{ClientIP LM ?Uri}
   P={{LM getLayer('dist-layer:process' $)} init()}
in
   Uri='address-client:IPSocket'
   class from Session
      meth init(A Process)
	 Done={NewCell false} in
	 for
	    H in A.hosts
	    while:{Not @Done}
	 do
	    try
	       S={New Open.socket client(host:H port:A.port)}
	       Conn={New SocketConnection init(S {P here($)})}
	    in
	       if {Conn getProcess($)}.id=={Process thisProcess($)}.id then
		  {Process connection(add Conn)}
		  Done:=true
	       else
		  {Conn close()}
	       end
	    catch _ then
	       skip
	    end
	 end
      end
   end
end
end