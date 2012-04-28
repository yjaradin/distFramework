declare
Dir='/Users/matthieusieben/Desktop/distFramework/'
[D DE]={Link [Dir#'distBase.ozf' Dir#'distExtra.ozf']}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
DP#FLRef = {Pickle.load Dir#'connect.p'}

FL={L serviceFromRef(FLRef Browse $)}
{Browse FL}

{FL send(DP world)}

{Browse FLRef}
for I in 1;I<50;I+1 do
   {FL send(DP sheep(I))}
end
