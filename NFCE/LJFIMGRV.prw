#include "totvs.ch"
//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:LJFIMGRV.prw
        Funcao:LJFIMGRV
        Autor:Guilherme Muniz
        Data:28/07/2016
        Descricao:Ponto de entrada executado ao final do processamento da rotina LjGrvTran (LOJXFUNC.PRW) 
    /*/
//--------------------------------------------------------------------------------------------------------------
    /*/

                10        20        30        40        50        60        70        80        90       100
        12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234
        +------------------------------------------------------------------------------------------------------+
        |                             ALTERACOES SOFRIDAS DESDE A VERSAO ORIGINAL:                             |
        +----------+-----------------------------------------------+-------------------------------------------+
        |   DATE   |                     AUTOR                     |                  MOTIVO                   |
        +----------+-----------------------------------------------+-------------------------------------------+
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Importação NFCe/RJ                        |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
User Function LJFIMGRV()
                         	
	Local aArea
	Local aAreaL1
	Local aAreaL2
	Local aAreaF2
	Local aAreaD2
	
	Local cSF2Filial
	Local cSD2Filial
	Local cSL2Filial
	
	Local lL1XVALICM

	Local nBase
	Local nValor                  

	aArea:=GetArea()       
	aAreaL1:=SL1->(GetArea())
	aAreaL2:=SL2->(GetArea())
	aAreaF2:=SF2->(GetArea())
	aAreaD2:=SD2->(GetArea())

	cSF2Filial:=xFilial("SF2")           
	cSD2Filial:=xFilial("SD2")
	cSL2Filial:=xFilial("SL2")
	
	CONOUT("[LJFIMGRV] - INICIO            - Empresa: "+SM0->M0_CODIGO+" Filial: "+SM0->M0_CODFIL)
	CONOUT("[LJFIMGRV] - PROCESSANDO       - NF     : "+SL1->(L1_FILIAL+L1_DOC+L1_SERIE+L1_CLIENTE+L1_LOJA))
	CONOUT("[LJFIMGRV] - TEMPO DE EXECUCAO - DATA   : "+DToC(dDataBase)+" Hora: "+Time())
	
	lL1XVALICM:=SL1->(FieldPos("L1_XVALICM")>0)
	
	SF2->(dbSetOrder(1))
	If SF2->(dbSeek(cSF2Filial+SL1->(L1_DOC+L1_SERIE+L1_CLIENTE+L1_LOJA))).And.SL1->(lL1XVALICM.And.L1_XVALICM!=SF2->F2_VALICM)
	
		SD2->(dbSetOrder(3))
		SD2->(dbSeek(cSF2Filial+SF2->(F2_DOC+F2_SERIE+F2_CLIENTE+F2_LOJA)))
	
		Begin Transaction
			
			nBase:=nValor:=0
			
			While SD2->(!EOF().And.cSD2Filial+SD2->(D2_DOC+D2_SERIE+D2_CLIENTE+D2_LOJA)==xFilial("SF2")+SF2->(F2_DOC+F2_SERIE+F2_CLIENTE+F2_LOJA))
		
				SL2->(dbSetOrder(1))
				If SL2->(dbSeek(cSL2Filial+SL1->L1_NUM+SD2->D2_ITEM+SD2->D2_COD))
				
					If SD2->(RecLock("SD2",.F.))
						SD2->D2_BASEICM:=SL2->L2_XBASICM
						SD2->D2_PICM:=SL2->L2_XALQICM
						SD2->D2_VALICM:=SL2->L2_XVALICM
						SD2->(MsUnlock())
					EndIf
					
					If SL2->(RecLock("SL2",.F.))
						SL2->L2_VALICM:=SL2->L2_XVALICM
						SL2->L2_BASEICM:=SL2->L2_XBASICM
						SL2->(MsUnlock())
					EndIf
					
				EndIf
				
				nBase+=SD2->D2_BASEICM
				nValor+=SD2->D2_VALICM
				
				SD2->(dbSkip())
			
			EndDO  
			
			If SF2->(RecLock("SF2",.F.))
				SF2->F2_BASEICM:=nBase
				SF2->F2_VALICM:=nValor
				SF2->(MsUnlock())
			EndIf 
			
			If SL1->(RecLock("SL1",.F.))
				IF SL1->(FieldPos("L1_BASEICM")>0)
					SL1->L1_BASEICM:=nBase
				ElseIF SL1->(FieldPos("L1_XBASICM")>0)
					SL1->L1_XBASICM:=nBase					
				ENDIF
				IF SL1->(FieldPos("L1_VALICM")>0)
					SL1->L1_VALICM:=nValor
				ElseIF SL1->(FieldPos("L1_XVALICM")>0)
					SL1->L1_XVALICM:=nValor
				ENDIF				
				SL1->(MsUnlock())
			EndIf
		
		End Transaction	
		
	EndIf
	
	CONOUT("[LJFIMGRV] - TEMPO DE EXECUCAO - DATA: "+DToC(dDataBase)+" Hora: "+Time())
	CONOUT("[LJFIMGRV] - PROCESSANDO       - NF: "+SL1->(L1_FILIAL+L1_DOC+L1_SERIE+L1_CLIENTE+L1_LOJA))
	CONOUT("[LJFIMGRV] - FIM               - Empresa: "+SM0->M0_CODIGO+" Filial: "+SM0->M0_CODFIL)
	                 
	RestArea(aAreaD2)
	RestArea(aAreaF2)
	RestArea(aAreaL2)
	RestArea(aAreaL1)
	RestArea(aArea)

Return( NIL )