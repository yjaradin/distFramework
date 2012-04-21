declare
[D DE]={Link ['/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/distBase.ozf'
	      '/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/distExtra.ozf'
	     ]}
{Wait D}
{DE.load}

L={New D.localProcess init()}
{Browse {L getProcess($)}}
DP#FLRef = {Pickle.load '/Users/matthieusieben/Documents/UCL/INGI21MS/Q2/SINF2345/project/distFramework/connect.p'}

FL={L serviceFromRef(FLRef Browse $)}
{Browse FL}

{FL send(DP world)}

{Browse FLRef}
for I in 1;I<50;I+1 do
   {FL send(DP sheep(I))}
end
