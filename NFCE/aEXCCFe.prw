#INCLUDE "PROTHEUS.CH"
//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:AEXCCFE.prw
        Funcao:AEXCCFE
        Autor:TOTALIT
        Data:26/07/2016
        Descricao: Limpar Dados para Recarga do XML
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
User Function aEXCCFe()

	Local cPerg
	
	cPerg:="EXCCFE"
	CriaSX1(cPerg)
	
	If !Pergunte(cPerg,.T.)
		Return(NIL)
	EndIf        
	
	Private lDelete := .T.
	Processa({||RunProc()},OemToAnsi("Aguarde"),OemToAnsi("Processando os dados ..."))
	
Return(NIL)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:AEXCCFE.prw
        Funcao:RunProc
        Autor:TOTALIT
        Data:26/07/2016
        Descricao: Chamada do Procedimento
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
Static Function RunProc()  
	
	Local nI
	Local nCount
	Local nSZGRecNO
	
	Local cCount
	Local cQuery
	Local cAlias
	Local cAliasQry
	Local cEmissaoDe
	Local cEmissaoAte
	
	Local lZGEMISSAO

	cEmissaoDe:=DTOS(MV_PAR05)
	cEmissaoAte:=DTOS(MV_PAR06)

	lZGEMISSAO:=SZG->(FieldPos("ZG_EMISSAO")>0)
	if (lZGEMISSAO)
		cQuery:="SZG.ZG_EMISSAO"
	else
		if (mv_par15==1)		//SP
			cQuery:="substr(replace(replace(utl_raw.cast_to_varchar2(DBMS_LOB.SUBSTR(SZG.ZG_XML,1000,1)),chr(13),''),chr(10),''),268,8)"
		elseif (mv_par15==2)	//RJ
			cQuery:="replace(substr(replace(replace(utl_raw.cast_to_varchar2(DBMS_LOB.SUBSTR(SZG.ZG_XML,1000,1)),chr(13),''),chr(10),''),392,10),'-','')"
		else
			cQuery:="1=1"
		endif
	endif
	
	cQuery:="%"+cQuery+"%"

	cAlias:=GetNextAlias()
	BEGINSQL ALIAS cAlias
		%NoParser%
		SELECT SZG.R_E_C_N_O_ nSZGRECNO
		  FROM %table:SZG% SZG
		 WHERE
		 (
	              SZG.%NotDel%    
			  AND SZG.ZG_FILIAL	 BETWEEN %exp:MV_PAR01% AND %exp:MV_PAR02%
			  AND SZG.ZG_ARQUIVO BETWEEN %exp:MV_PAR03% AND %exp:MV_PAR04%
			  AND SZG.ZG_STATUS  BETWEEN %exp:MV_PAR07% AND %exp:MV_PAR08%
			  AND SZG.ZG_ORCAME  BETWEEN %exp:MV_PAR09% AND %exp:MV_PAR10%
			  AND SZG.ZG_DOC     BETWEEN %exp:MV_PAR11% AND %exp:MV_PAR12%
		      AND SZG.ZG_SERIE   BETWEEN %exp:MV_PAR13% AND %exp:MV_PAR14%
		 )
		 AND (%exp:cQuery% BETWEEN %exp:cEmissaoDe% AND %exp:cEmissaoAte%)
		ORDER BY SZG.R_E_C_N_O_
	ENDSQL
	
	cQuery:=GetLastQuery()[2]
	cQuery:="%"+cQuery+"%"
	
	cAliasQry:=GetNextAlias()
	BEGINSQL ALIAS cAliasQry
		%NoParser%
		SELECT COUNT(*) AS TOTAL
		  FROM (%exp:cQuery%) t
	ENDSQL	
	
	nCount:=(cAliasQry)->TOTAL
	(cAliasQry)->(dbCloseArea())
	dbSelectArea(cAlias)

	cCount:=AllTrim(Str(nCount))
	ProcRegua(nCount)

	nI:=0      

	SF2->(dbSetOrder(1))
	SD2->(dbSetOrder(3))
	SF3->(dbSetOrder(6))
	SFT->(dbSetOrder(1))
	CD2->(dbSetOrder(1))
	SE1->(dbSetOrder(1))
	SL1->(dbSetOrder(1))
	SL2->(dbSetOrder(1))
	SL4->(dbSetOrder(1))
	MH2->(dbSetOrder(1))

	While (cAlias)->(!EOF())
		nSZGRecNO:=(cAlias)->nSZGRECNO
		SZG->(dbGoTo(nSZGRecNO))
		BEGIN TRANSACTION
			limpaBase()        	
		END TRANSACTION
		IncProc("Processando "+AllTrim(Str(++nI))+"/"+cCount)	
		(cAlias)->(dbSkip())
	EndDO
	
	(cAlias)->(dbCloseArea())
	dbSelectArea("SZG")
           
Return(NIL)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:AEXCCFE.prw
        Funcao:limpaBase
        Autor:TOTALIT
        Data:26/07/2016
        Descricao: Limpa os Dados para Recarga dos XMLs
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
Static Function limpaBase()

	if !lDelete
		return( .F. )
	endif

	CD2->( dbSeek( SZG->( xFilial("CD2",SZG->ZG_FILIAL)+"S"+ZG_SERIE+ZG_DOC ) ))
	while CD2->( !eof() .and. xFilial("CD2",SZG->ZG_FILIAL)+CD2_TPMOV+CD2_SERIE+CD2_DOC == SZG->( xFilial("CD2",SZG->ZG_FILIAL)+"S"+ZG_SERIE+ZG_DOC ) )
		if CD2->( recLock("CD2",.F.) )
			CD2->( dbDelete() )
			CD2->( msUnlock() )
		endif
		CD2->( dbSkip() )
	end while
	
	SFT->( dbSeek( SZG->( xFilial("SFT",SZG->ZG_FILIAL)+"S"+ZG_SERIE+ZG_DOC ) ) )
	while SFT->( !eof() .and. xFilial("SFT",SZG->ZG_FILIAL)+FT_TIPOMOV+FT_SERIE+FT_NFISCAL == SZG->( xFilial("SFT",SZG->ZG_FILIAL)+"S"+ZG_SERIE+ZG_DOC ) )
		if SFT->( recLock("SFT",.F.) )
			SFT->( dbDelete() )
			SFT->( msUnlock() )
		endif
		SFT->( dbSkip() )
	end while
	
	SF3->( dbSeek( SZG->( xFilial("SF3",SZG->ZG_FILIAL)+ZG_DOC+ZG_SERIE ) ) )
	while SF3->( !eof() .and. xFilial("SF3",SZG->ZG_FILIAL)+F3_NFISCAL+F3_SERIE == SZG->( xFilial("SF3",SZG->ZG_FILIAL)+ZG_DOC+ZG_SERIE ) )
		if LEFT(SF3->F3_CFO,1) >= '5'
			if SF3->( recLock("SF3",.F.) )
				SF3->( dbDelete() )
				SF3->( msUnlock() )
			endif
		endif
		SF3->( dbSkip() )
	end while
	
	SD2->( dbSeek( SZG->( xFilial("SD2",SZG->ZG_FILIAL)+ZG_DOC+ZG_SERIE ) ) )
	while SD2->( !eof() .and. xFilial("SD2",SZG->ZG_FILIAL)+D2_DOC+D2_SERIE == SZG->( xFilial("SD2",SZG->ZG_FILIAL)+ZG_DOC+ZG_SERIE ) )
		if SD2->( recLock("SD2",.F.) )
			SD2->( dbDelete() )
			SD2->( msUnlock() )
		endif
		SD2->( dbSkip() )
	end while
	
	if SF2->( dbSeek( SZG->( xFilial("SF2",SZG->ZG_FILIAL)+ZG_DOC+ZG_SERIE ) ) )
	
		SE1->(DbSetOrder(RetOrder("SE1","E1_FILIAL+E1_PREFIXO+E1_NUM+E1_PARCELA+E1_TIPO")))
		SE1->( dbSeek( SF2->( xFilial("SE1",SF2->F2_FILIAL)+F2_PREFIXO+F2_DUPL ) ) )
		while SE1->( !eof() .and. SE1->(xFilial("SE1",SF2->F2_FILIAL)+E1_PREFIXO+E1_NUM) == SF2->( xFilial("SE1",SF2->F2_FILIAL)+F2_PREFIXO+F2_DUPL ) )
			
			if (SF2->F2_FILIAL==SE1->E1_FILORIG)
				DbSelectarea("SE5")            
				SE5->(DbSetOrder(RetOrder("SE5","E5_FILIAL+E5_PREFIXO+E5_NUMERO+E5_PARCELA+E5_TIPO+E5_CLIFOR+E5_LOJA+E5_SEQ+E5_RECPAG")))
				If SE5->(DbSeek(xFilial("SE5",SF2->F2_FILIAL)+SE1->(E1_PREFIXO+E1_NUM+E1_PARCELA+E1_TIPO)))
				   recLock("SE5",.F.)
				   SE5->( dbDelete() )
				   SE5->( msUnlock() )
				EndIf
				
				if SE1->( recLock("SE1",.F.) )
					SE1->( dbDelete() )
					SE1->( msUnlock() )
				endif
			endif
			
			SE1->( dbSkip() )
		
		end while

		if SF2->( recLock("SF2",.F.) )
			SF2->( dbDelete() )
			SF2->( msUnlock() )
		endif

	endif
			
	SE1->(DbSetOrder(RetOrder("SE1","E1_FILIAL+E1_PREFIXO+E1_NUM+E1_PARCELA+E1_TIPO")))
	SE1->( dbSeek( SZG->( xFilial("SE1",SZG->ZG_FILIAL)+ZG_SERIE+ZG_DOC ) ) )
	while SE1->( !eof() .and. xFilial("SE1",SF2->F2_FILIAL)+E1_PREFIXO+E1_NUM == SZG->( xFilial("SE1",SZG->ZG_FILIAL)+ZG_SERIE+ZG_DOC ) )
		if (SZG->ZG_FILIAL==SE1->E1_FILORIG)
			if SE1->( recLock("SE1",.F.) )
				SE1->( dbDelete() )
				SE1->( msUnlock() )
			endif
		endif
		SE1->( dbSkip() )
	end while
	  
	SL4->( dbSeek( SZG->( xFilial("SL4",SZG->ZG_FILIAL)+ZG_ORCAME ) ) )
	while SL4->( !eof() .and. xFilial("SL4",SZG->ZG_FILIAL)+L4_NUM == SZG->( xFilial("SL4",SZG->ZG_FILIAL)+ZG_ORCAME ) )
		if SL4->( recLock("SL4",.F.) )
			SL4->( dbDelete() )
			SL4->( msUnlock() )
		endif
		SL4->( dbSkip() )
	end while
	
	SL2->( dbSeek( SZG->( xFilial("SL2",SZG->ZG_FILIAL)+ZG_ORCAME ) ) )
	while SL2->( !eof() .and. xFilial("SL2",SZG->ZG_FILIAL)+L2_NUM == SZG->( xFilial("SL2",SZG->ZG_FILIAL)+ZG_ORCAME ) )
		if SL2->( recLock("SL2",.F.) )
			SL2->( dbDelete() )
			SL2->( msUnlock() )
		endif
		SL2->( dbSkip() )
	end while
	
	SL1->( dbSeek( SZG->( xFilial("SL1",SZG->ZG_FILIAL)+ZG_ORCAME ) ) )
	while SL1->( !eof() .and. xFilial("SL1",SZG->ZG_FILIAL)+L1_NUM == SZG->( xFilial("SL1",SZG->ZG_FILIAL)+ZG_ORCAME ) )
		if SL1->( recLock("SL1",.F.) )
			SL1->( dbDelete() )
			SL1->( msUnlock() )
		endif
		SL1->( dbSkip() )
	end while
	
	if MH2->( dbSeek( SZG->( xFilial("MH2",SZG->ZG_FILIAL)+ZG_ORCAME ) ) )
		if MH2->(recLock("MH2",.F.))
			MH2->( dbDelete() )
			MH2->( msUnlock() )
		endif
		MH2->( dbSkip() )
	endif
	
	if RecLock("SZG",.F.)
		SZG->( dbDelete() )
		SZG->( MsUnlock() )
	endif
	
Return( .T. )       

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:AEXCCFE.prw
        Funcao:CriaSX1
        Autor:TOTALIT
        Data:26/07/2016
        Descricao: Cria as Perguntas a sere utilizadas no Programa
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
Static Function CriaSX1(cPerg)

	cPerg:=PadR(cPerg,Len(SX1->X1_GRUPO))
	
	PutSX1(cPerg,"01","De Filial ?  ","","","mv_ch1","C",TamSX3("ZG_FILIAL")[1],0,0,"G","          ","XM0","033","","mv_par01","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"02","Ate Filial ? ","","","mv_ch2","C",TamSX3("ZG_FILIAL")[1],0,0,"G","NaoVazio()","XM0","033","","mv_par02","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"03","De Arquivo ? ","","","mv_ch3","C",99					   ,0,0,"G","          ","   ","   ","","mv_par03","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"04","Ate Arquivo? ","","","mv_ch4","C",99                    ,0,0,"G","NaoVazio()","   ","   ","","mv_par04","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"05","De Data ?    ","","","mv_ch5","D",08                    ,0,0,"G","          ","   ","   ","","mv_par05","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"06","Ate Data ?   ","","","mv_ch6","D",08                    ,0,0,"G","NaoVazio()","   ","   ","","mv_par06","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"07","De Status ?  ","","","mv_ch7","C",TamSX3("ZG_STATUS")[1],0,0,"G","          ","   ","   ","","mv_par07","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"08","Ate Status?  ","","","mv_ch8","C",TamSX3("ZG_STATUS")[1],0,0,"G","NaoVazio()","   ","   ","","mv_par08","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"09","De No Orc. ? ","","","mv_ch9","C",TamSX3("ZG_ORCAME")[1],0,0,"G","          ","   ","   ","","mv_par09","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"10","Ate No Orc.? ","","","mv_cha","C",TamSX3("ZG_ORCAME")[1],0,0,"G","NaoVazio()","   ","   ","","mv_par10","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"11","De Doc ?     ","","","mv_chb","C",TamSX3("ZG_DOC")[1]   ,0,0,"G","          ","   ","   ","","mv_par11","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"12","Ate Doc ?    ","","","mv_chc","C",TamSX3("ZG_DOC")[1]   ,0,0,"G","NaoVazio()","   ","   ","","mv_par12","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"13","De Serie ?   ","","","mv_chd","C",TamSX3("ZG_SERIE")[1] ,0,0,"G","          ","   ","   ","","mv_par13","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"14","Ate Serie ?  ","","","mv_che","C",TamSX3("ZG_SERIE")[1] ,0,0,"G","NaoVazio()","   ","   ","","mv_par14","  ","","","","  ","","","","","","","","","","","",{},{},{})
	PutSX1(cPerg,"15","Estado ?     ","","","mv_chf","N",1                     ,0,1,"C","          ","   ","   ","","mv_par15","SP","","","","RJ","","","","","","","","","","","",{},{},{})
	
Return( NIL )