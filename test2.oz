declare
[D DE]={Link ['/home/yjaradin/SINF2345/distBase.ozf'
	      '/home/yjaradin/SINF2345/distExtra.ozf'
	     ]}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
DP#FLRef = {Pickle.load '/home/yjaradin/SINF2345/connect.p'}

FL={L serviceFromRef(FLRef Browse $)}
{Browse FL}

{FL send(DP world)}
{Browse FLRef}
for I in 1;I<200;I+1 do
   {FL send(DP sheep(I))}
end