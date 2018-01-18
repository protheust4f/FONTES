#Include "Rwmake.ch"

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
ฑฑษออออออออออัออออออออออหอออออออัออออออออออออออออออออหออออออัอออออออออออออปฑฑ
ฑฑบPrograma  ณLJ010SF3  บAutor  ณRegiane R. Barreira บData  ณ25/04/06     บฑฑ
ฑฑฬออออออออออุออออออออออสอออออออฯออออออออออออออออออออสออออออฯอออออออออออออนฑฑ
ฑฑบDesc.     ณPonto de Entrada, para impressใo das Fichinhas.			  บฑฑ
ฑฑฬออออออออออุออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออนฑฑ
ฑฑณSintaxe   ณ Execblock("LJ010SF3",.F.,.F.)  		                      บฑฑ
ฑฑฬออออออออออุออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออนฑฑ
ฑฑบUso       ณ LOJA701					                                  บฑฑ
ฑฑศออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผฑฑ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿
*/
User Function LJ010SF3()

	local lLJ010SF3
	
	lLJ010SF3:=!EMPTY(retSQLname("PA3")).and.!EMPTY(retSQLname("PA5"))

	if (lLJ010SF3)
		LJ010SF3()
	endif

Return(lLJ010SF3)

Static Function LJ010SF3()

Local aArea		:= GetArea()
Local cLjFicha	:= GetNewPar( "ES_LJFICHA", .F. )		//Imprime ou nใo as fichinhas
Local cDShow    := ""									//Descricao do Show
Local aDShow	:= {} 									//Descricao do Show por linhas
Local nShow     := 0									//Variavel auxiliar
Local cLjMsgFi	:= AllTrim(GetNewPar("ES_LJMSGFI",""))	//Mensagem configurada no parametro
Local aLjMsgFi	:= {} 									//Mensagem configurada no parametro por linhas
Local nMsgFi    := 0									//Variavel auxiliar
Local cFicha	:= ""									//Mensagem impressa no comprovante nao-fiscal
Local nTotCol	:= 48	   								//Total de colunas no ECF
Local nQuant	:= 0									//Quantidade do produto
Local nLoop,i,j 										//Variaveis do for

If cLjFicha 

	dbSelectArea("PA3")	//Configuracao Adicional de Estacao
	dbSetorder(1) // PA3_FILIAL+PA3_CODEST
	If dbSeek(xFilial("PA3")+ cEstacao)

		If PA3->PA3_IMFICH == "1"	//SIM

			//ฺฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฟ
			//ณMonta texto com a descricao do show.									 ณ
			//ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤู
			cDShow := AllTrim(Posicione("PA5",1,xFilial("PA5")+SL1->L1_CODSHOW,"PA5_DESCRI"))
			nShow := Int(Len(cDShow) / nTotCol) + 1
			For i := 1 to nShow
				aAdd(aDShow, SubStr(cDShow, (i * nTotCol) - nTotCol + 1, nTotCol))
			Next i
			nShow := Len(aDShow)
			
			//ฺฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฟ
			//ณMonta texto com a mensagem.											 ณ
			//ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤู
			If Len(cLjMsgFi) > 0
				nMsgFi := Int(Len(cLjMsgFi) / nTotCol) + 1
				For i := 1 to nMsgFi
					aAdd(aLjMsgFi, SubStr(cLjMsgFi, (i * nTotCol) - nTotCol + 1, nTotCol))
				Next i
				nMsgFi := Len(aLjMsgFi)
			EndIf
			
			dbSelectArea("SD2")
			dbSetorder(3) // D2_FILIAL+D2_DOC+D2_SERIE+D2_CLIENTE+D2_LOJA+D2_COD+D2_ITEM
			dbSeek(SF2->(F2_FILIAL + F2_DOC + F2_SERIE + F2_CLIENTE + F2_LOJA))
				
			While !EOF().And. D2_FILIAL == SF2->F2_FILIAL .And. D2_DOC == SF2->F2_DOC .And.;
				D2_SERIE == SF2->F2_SERIE .And. D2_CLIENTE == SF2->F2_CLIENTE .And. D2_LOJA == SF2->F2_LOJA
			
				nQuant := D2_QUANT
				
				//ฺฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฟ
				//ณMonta texto das fichinhas.											 ณ
				//ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤู
				For nLoop := 1 to nQuant
					cFicha	:= ""	
					
					cFicha += PADR("", nTotCol)
					cFicha += PADR("", nTotCol)

					For j := 1 to nShow
						cFicha += PADR(aDShow[j], nTotCol)
					Next j
			
					cFicha += PADR("Data: " + DToC(dDataBase) + " as " + Time(), nTotCol)
					cFicha += PADR("", nTotCol)
					cFicha += PADR("Cod. Produto: " + AllTrim(SD2->D2_COD) + " 1 " + Alltrim(Posicione("SB1",1,xFilial("SB1")+SD2->D2_COD,"B1_UM")),nTotCol)
					cFIcha += PADR(Alltrim(Posicione("SB1",1,xFilial("SB1")+SD2->D2_COD,"B1_DESC")),nTotCol)
					cFicha += PADR("", nTotCol)

					If Len(cLjMsgFi) > 0
						For j := 1 to nMsgFi
							cFicha += PADR(aLjMsgFi[j], nTotCol)
						Next j
					EndIf

					cFicha += PADR("", nTotCol)
					cFicha += PADR("", nTotCol)

					//ฺฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฟ
					//ณEnvia o relat๓rio para a impressora                    ณ
					//ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤู
					nRet := IFRelGer( nHdlECF, cFicha, 1 )
			
					If nRet <> 0
						MsgStop("Problemas com a Impressora Fiscal")
					Endif
			
				Next
			
				SD2->(dbSkip())
			EndDo
		EndIf
	EndIf
EndIf	

//ฺฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฟ
//ณGrava item contabil disponivel no cadastro de shows	  ณ
//ภฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤู
DbSelectArea( "SL2" )
DbSetOrder( 1 )
MsSeek( xFilial( "SL2" ) + SL1->L1_NUM )

While !Eof() .AND. SL2->L2_FILIAL + SL2->L2_NUM == xFilial( "SL2" ) + SL1->L1_NUM
//	Begin Transaction 

		RecLock("SL2",.F.)
			SL2->L2_ITEMCC := Posicione("PA5",1,xFilial("PA5")+SL1->L1_CODSHOW,"PA5->PA5_ITEMCO")
		MsUnlock()
		
//	End Transaction
	SL2->(DbSkip())
Enddo

RestArea(aArea)  


Return()