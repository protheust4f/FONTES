#INCLUDE "PROTHEUS.CH"
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³AEXCCFE   ºAutor  ³Microsiga           º Data ³  07/26/16   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³                                                            º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                        º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
User Function LimpaSL1()


Processa({|| RunProc()},OemToAnsi("Aguarde"),OemToAnsi("Processando os dados ..."))

Return( Nil )


Static Function RunProc()

Local cQuery := " "
Local _cAlias := GetArea()
Local nI := 0
Local nCount := 0         
Local cAlias

SF2->( dbSetOrder(1) )
SD2->( dbSetOrder(3) )
SF3->( dbSetOrder(6) )
SFT->( dbSetOrder(1) )
CD2->( dbSetOrder(1) )
SE1->( dbSetOrder(2) )
SL1->( dbSetOrder(2) )
SL2->( dbSetOrder(3) )
SL4->( dbSetOrder(1) )
MH2->( dbSetOrder(1) )




cQuery := " SELECT L1_FILIAL,L1_NUM, L1_DOC, L1_SERIE, L1_EMISNF "
cQuery += " FROM "+RetSqlName("SL1")+" "
cQuery += " WHERE L1_FILIAL = '"+xFilial("SL1")+"' AND D_E_L_E_T_ = ' ' " 
cQuery += " AND L1_EMISNF BETWEEN '20160501' AND '20161231' "

/*
cQuery := " SELECT F2_FILIAL, F2_DOC, F2_SERIE "
cQuery += " FROM "+RetSqlName("SF2")+" "
cQuery += " WHERE F2_FILIAL = '"+xFilial("SF2")+"' AND D_E_L_E_T_ = ' ' " 
cQuery += " AND F2_ESPECIE = 'NFCE' "
cQuery += " AND F2_EMISSAO BETWEEN '20160601' AND '20160831' "
*/

cQuery := ChangeQuery(cQuery)

cAlias := "TMPF2"
dbUseArea(.T., "TOPCONN", TCGenQry(,,cQuery), cAlias, .F., .T.)
          
If (cAlias)->(!EOF())
	(cAlias)->(dbEval( {|| nCount++ }))
EndIf

ProcRegua(nCount)

dbSelectArea(cAlias)
dbGoTop()

While (cAlias)->(!EOF())
  
	nI++	
	IncProc("Processando " + AllTrim(Str(nI)) + " de " + AllTrim(Str(nCount)))	
	
DbSelectArea("SL1")
SL1->(DbSetOrder(1))

If SL1->( dbSeek( (cAlias)->( L1_FILIAL+L1_NUM) ) )
	
	CD2->( dbSeek( SL1->(L1_FILIAL+"S"+L1_SERIE+L1_DOC ) ))
	while CD2->( !eof() .and. CD2_FILIAL+CD2_TPMOV+CD2_SERIE+CD2_DOC == SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) )
		recLock("CD2",.F.)
		CD2->( dbDelete() )
		CD2->( msUnlock() )
		CD2->( dbSkip() )
	end
	
	SFT->( dbSeek( SL1->(L1_FILIAL+"S"+L1_SERIE+L1_DOC ) ) )
	while SFT->( !eof() .and. FT_FILIAL+FT_TIPOMOV+FT_SERIE+FT_NFISCAL == SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) )
		recLock("SFT",.F.)                                                             
		SFT->( dbDelete() )
		SFT->( msUnlock() )
		SFT->( dbSkip() )
	end
	
	SF3->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
	while SF3->( !eof() .and. F3_FILIAL+F3_NFISCAL+F3_SERIE == SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) )
		if LEFT(SF3->F3_CFO,1) >= '5'
			recLock("SF3",.F.)
			SF3->( dbDelete() )
			SF3->( msUnlock() )
		endif
		SF3->( dbSkip() )
	end

	SF2->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
	while SF2->( !eof() .and. F2_FILIAL+F2_DOC+F2_SERIE == SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) )
		recLock("SF2",.F.)
		SF2->( dbDelete() )
		SF2->( msUnlock() )
		SF2->( dbSkip() )
	end
	
	SD2->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
	while SD2->( !eof() .and. D2_FILIAL+D2_DOC+D2_SERIE == SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) )
		recLock("SD2",.F.)
		SD2->( dbDelete() )
		SD2->( msUnlock() )
		SD2->( dbSkip() )
	end
	
	/*
   
    SE1->( dbSetOrder(2) )
	SE1->( dbSeek( SL1->( L1_FILIAL+L1_CLIENTE+L1_LOJA+L1_PREFIXO+L1_DUPL ) ) )
	while SE1->( !eof() .and. E1_FILIAL+E1_CLIENTE+E1_LOJA+E1_PREFIXO+E1_NUM == SF2->( F2_FILIAL+F2_CLIENTE+F2_LOJA+F2_PREFIXO+F2_DUPL ) )
		recLock("SE1",.F.)
		SE1->( dbDelete() )
		SE1->( msUnlock() )
		SE1->( dbSkip() )
	end
	  */
	  
	SL1->(DbSetOrder(1))
	SL1->( dbSeek( (cAlias)->( L1_FILIAL+L1_NUM) ) )	
	SL4->(DbSetOrder(1))
	SL4->(DbSeek(SL1->(L1_FILIAL+L1_NUM)))
	while SL4->( !eof() .and. L4_FILIAL+L4_NUM == SL1->( L1_FILIAL+L1_NUM) )
		recLock("SL4",.F.)
		SL4->( dbDelete() )
		SL4->( msUnlock() )
		SL4->( dbSkip() )
	end
	
	
	if MH2->( dbSeek( SL1->(L1_FILIAL+L1_NUM) ) )
	    recLock("MH2",.F.)
	    MH2->( dbDelete() )
    	MH2->( msUnlock() )
    	MH2->( dbSkip() )
    endIf

	
	SL2->(DbSetOrder(1))
	SL2->( dbSeek( (cAlias)->( L1_FILIAL+L1_NUM) ) )
	while SL2->( !eof() .and. L2_FILIAL+L2_NUM == SL1->( L1_FILIAL+L1_NUM) )
		recLock("SL2",.F.)
		SL2->( dbDelete() )
		SL2->( msUnlock() )
		SL2->( dbSkip() )
	end
	
	recLock("SL1",.F.)
	SL1->( dbDelete() )
	SL1->( msUnlock() )
	SL1->( dbSkip() )
	
endif

(cAlias)->(Dbskip())

End    

(cAlias)->(dbCloseArea())
RestArea(_cAlias)

Return

