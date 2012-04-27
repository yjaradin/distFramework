functor
import
   Pickle
   Error
   Open
   OS
export
   LocalProcess
   Services
   Load
   BaseService
   p2p:P2P
define
   Services={Dictionary.new}
   Incoming={Dictionary.new}
   Outgoing={Dictionary.new}
   
   class LocalProcess
      attr
	 pid
	 addr
	 server
      meth init(Host<=unit) Port in
	 pid := {NewName}
	 Incoming.@pid := {Dictionary.new}
	 Outgoing.@pid := {New Loopback init(self)}
	 server := {New TcpServer init(self Port)}
	 addr := if Host==unit then
		    a({OS.getHostByName "localhost"}.addrList.1 Port)
		 else
		    a(Host Port)
		 end
      end
      meth getProcess($)
	 p(pid:@pid addr:@addr)
      end
      meth newService(Init Listener $)
	 {New Services.{Label Init} preInit(self true Init Listener)}
      end
      meth serviceFromRef(SRef Listener $)
	 {New Services.{Label SRef} preInit(self false SRef Listener)}
      end
   end

   class BaseService
      attr
	 kind
	 this
	 thisP
	 up
	 sid
      meth preInit(LocalP IsNew Init Listener)
	 this := LocalP
	 thisP := {LocalP getProcess($)}
	 kind := {Label Init}
	 up := Listener
	 if IsNew then
	    sid := {NewName}
	    {self {Record.adjoin Init init}}
	 else
	    sid := Init.sid
	    {self Init.p}
	 end
      end
      meth init(...) skip end
      meth wrap($ ...)=Mapping
	 proc{$ Msg}
	    {self {Record.adjoin Msg Mapping.{Label Msg}}}
	 end
      end
      meth getRef($)
	 L=@kind in
	 L(sid:@sid p:{self getRefParams($)})
      end
      meth halt
	 {self haltDown}
	 up:=DropMsg
      end
      meth haltDown skip end
      meth getRefParams($) init() end
   end

   class P2P
      from BaseService
   end

   proc{DropMsg _} skip end
   proc{ProcessMessage ToId MsgP}
      if MsgP\=nil then
	 Msg={Pickle.unpack MsgP} in
	 case Msg
	 of flp2p(Sid Origin Content) then
	    thread
	       {{Dictionary.condGet Incoming.ToId Sid DropMsg} deliver(Origin Content)}
	    end
	 end
      end
   end
   class FLP2P
      from P2P
      meth init()
	 Incoming.(@thisP.pid).@sid := @up
      end
      meth send(To Msg)
	 if {OS.rand} mod 1000 <100 then {self send(To Msg)} end %Dup rate
	 if {OS.rand} mod 1000 <900 then %No-drop rate
	    thread
	       {Delay {OS.rand} mod 200} %Better distribution needed
	       {{GetConnection To} send({Pickle.pack flp2p(@sid @thisP Msg)})}
	    end
	    {Delay 100} %Delay by average delay to avoid thread explosion
	 end
      end
      meth haltDown
	 {Dictionary.remove Incoming.(@thisP.pid) @sid}
      end
   end
   Services.flp2p := FLP2P

   fun{GetConnection To}
      case {Dictionary.condGet Outgoing To.pid unit}
      of unit then N in
	 case {Dictionary.condExchange Outgoing To.pid unit $ N}
	 of unit then
	    N={New TcpClient init(To)}
	    N
	 [] C then N=C C
	 end
      [] C then C
      end
   end
   
   class Loopback
      attr lpId
      meth init(LocalP)
	 lpId := {LocalP getProcess($)}.pid
      end
      meth send(Msg)
	 {ProcessMessage @lpId Msg}
      end
   end

   fun{FromHex Cs}
      case Cs of nil then nil
      [] A|B|T then (A-&a)*16+(B-&a)|{FromHex T}
      end
   end
   class TcpServer
      attr
	 lpId
	 s
      meth init(LocalP P)
	 proc{Loop Xs} M Mr in
	    {List.takeDropWhile Xs fun{$ C}C\=&X end M Mr}
	    case Mr
	    of nil then skip
	    else
	       try
		  {ProcessMessage @lpId {FromHex M}}
	       catch E then
		  {Error.printException E}
	       end
	       {Loop Mr.2}
	    end
	 end
      in
	 lpId := {LocalP getProcess($)}.pid
	 s := {New Open.socket init()}
	 {@s bind(port:P)}
	 {@s listen()}
	 thread
	    for S from fun{$}{@s accept(accepted:$ acceptClass:Open.socket)}end do
	       thread
		  {Loop thread {S read(list:$ size:all)} end}
		  {S close()}
	       end
	    end
	 end
      end
   end

   fun{ToHex Cs}
      case Cs of nil then nil
      [] X|T then (X div 16 + &a)|(X mod 16 + &a)|{ToHex T}
      end
   end
   class TcpClient
      prop locking
      attr
	 rp
	 s
	 ok
	 unused
      meth init(RemoteP)
	 unused:=false
	 @rp = RemoteP
	 try
	    @s = {New Open.socket client(host:RemoteP.addr.1 port:RemoteP.addr.2)}
	    @ok=true
	    thread {self check} end
	 catch system(os(os "connect" ...) ...) then
	    @ok=false
	    {self destroy()}
	 [] E then
	    {Error.printException E}
	    @ok=false
	    {self destroy()}
	 end
      end
      meth send(Msg)
	 lock
	    if @ok then
	       unused:=false
	       try
		  {@s write(vs:{ToHex {VirtualString.toString Msg}})}
		  {@s write(vs:"X")}
	       catch system(os(os "write" ...) ...) then
		  ok:=false
		  {self destroy}
	       [] E then
		  {Error.printException E}
		  ok:=false
		  {self destroy}
	       end
	    end
	 end
      end
      meth destroy()
	 false=@ok
	 {@s close()}
	 thread
	    {Delay 1000}
	    {Dictionary.remove Outgoing @rp.pid}
	 end
      end
      meth check()
	 {Delay 5000}
	 lock
	    if @ok then
	       if @unused then
		  ok:=false
		  {self destroy}
	       else
		  unused:=true
	       end
	    end
	 end
	 if @ok then
	    {self check}
	 end
      end
   end
   proc{Load}skip end
end
