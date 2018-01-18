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
User Function aEXCT4F()

Local cPerg

//	cPerg:="EXCCFE"
//	CriaSX1(cPerg)

//	If !Pergunte(cPerg,.T.)
//		Return(NIL)
//	EndIf

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



/*

_Qry := " SELECT L1_FILIAL, L1_NUM, L1_PDV, L1_DOC, L1_SERIE, L1_EMISSAO, R_E_C_N_O_ AS REGNO "
_Qry += " FROM SL1200 WHERE L1_FILIAL = '01'                                    "
_Qry += " AND L1_EMISSAO BETWEEN '20160201' AND '20161231' AND D_E_L_E_T_ = ' ' AND L1_NUM = '618995' "
_Qry += " AND L1_SITUA = 'OK'  "

*/

_Qry := " SELECT L1_FILIAL, L1_NUM, L1_PDV, L1_DOC, L1_SERIE, L1_EMISSAO, R_E_C_N_O_ AS REGNO "
_Qry += " FROM SL1200 WHERE L1_FILIAL = '02'                                    "
_Qry += " AND L1_EMISSAO BETWEEN '20160301' AND '20160331' AND D_E_L_E_T_ = ' ' "
_Qry += " AND L1_SITUA = 'ER'  "


/*
_Qry := " SELECT L1_FILIAL, L1_NUM, L1_PDV, L1_DOC, L1_SERIE, L1_EMISSAO, R_E_C_N_O_ AS REGNO "
_Qry += " FROM SL1200 WHERE L1_FILIAL = '02'                                    "
_Qry += " AND L1_EMISSAO BETWEEN '20160201' AND '20161231' AND D_E_L_E_T_ = ' ' "
_Qry += " AND L1_SITUA = 'OK'  "
_Qry += " AND L1_NUM IN ( "
_Qry += " '643153','643527','643554','643555','644926','644929','643252','643265','643272','644998','643311','643324','643325','643328', "
_Qry += " '643335','643882','644181','644223','645057','643373','643375','643376','643378','643384','643414','643415','643967','644537', "
_Qry += " '644556','644558','643473','643479','643480','643497','644576')    "
_Qry += " AND L1_SERIE IN ('213','295','269','251','269','243','278','263')  "

*/

_Qry := ChangeQuery(_Qry)
dbUseArea(.T.,"TOPCONN", TCGenQry(,,_Qry), "TRB", .T., .T.)

dbSelectArea("TRB")

nCount := TRB->(Reccount())
TRB->(DbGotop())

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

While TRB->(!EOF())
	
	nSZGRecNO:=TRB->REGNO
	DbSelectArea("SL1")
	SL1->(dbGoTo(nSZGRecNO))
	BEGIN TRANSACTION
	limpaBase()
	END TRANSACTION
	IncProc("Processando "+AllTrim(Str(++nI))+"/"+Str(nCount))
	TRB->(dbSkip())
EndDO

TRB->(dbCloseArea())
dbSelectArea("SL1")

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



if SF2->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
	if recLock("SF2",.F.)
		SF2->( dbDelete() )
		SF2->( msUnlock() )
	endif
endif

If CD2->( dbSeek( SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) ))
while CD2->( !eof() .and. CD2_FILIAL+CD2_TPMOV+CD2_SERIE+CD2_DOC == SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) )
	if recLock("CD2",.F.)
		CD2->( dbDelete() )
		CD2->( msUnlock() )
	endif
	CD2->( dbSkip() )
end
EndIf

If SFT->( dbSeek( SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) ) )
while SFT->( !eof() .and. FT_FILIAL+FT_TIPOMOV+FT_SERIE+FT_NFISCAL == SL1->( L1_FILIAL+"S"+L1_SERIE+L1_DOC ) )
	if recLock("SFT",.F.)
		SFT->( dbDelete() )
		SFT->( msUnlock() )
	endif
	SFT->( dbSkip() )
end
EndIf

If SF3->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
while SF3->( !eof() .and. F3_FILIAL+F3_NFISCAL+F3_SERIE == SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) )
	if LEFT(SF3->F3_CFO,1) >= '5'
		if recLock("SF3",.F.)
			SF3->( dbDelete() )
			SF3->( msUnlock() )
		endif
	endif
	SF3->( dbSkip() )
end
EndIf

If SD2->( dbSeek( SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) ) )
while SD2->( !eof() .and. D2_FILIAL+D2_DOC+D2_SERIE == SL1->( L1_FILIAL+L1_DOC+L1_SERIE ) )
	if recLock("SD2",.F.)
		SD2->( dbDelete() )
		SD2->( msUnlock() )
	endif
	SD2->( dbSkip() )
end
endIf
SE1->(DbSetOrder(1))
If SE1->( dbSeek( SL1->( xFilial("SE1")+L1_SERIE+L1_DOC ) ) )
while SE1->( !eof() .and. SE1->(E1_FILIAL+E1_PREFIXO+E1_NUM) == SL1->( xFilial("SE1")+L1_SERIE+L1_DOC ))
	
	DbSelectarea("SE5")
	SE5->(DbSetOrder(7))
	If SE5->(DbSeek(xFilial("SE5")+SE1->(E1_PREFIXO+E1_NUM+E1_PARCELA+E1_TIPO+E1_CLIENTE+E1_LOJA)))
		recLock("SE5",.F.)
		SE5->( dbDelete() )
		SE5->( msUnlock() )
	EndIf
	
	recLock("SE1",.F.)
	SE1->( dbDelete() )
	SE1->( msUnlock() )
	SE1->( dbSkip() )
end
EndIf

If SE1->( dbSeek( SL1->( xFilial("SE1")+L1_SERIE+L1_DOC ) ) )
while SE1->( !eof() .and. SE1->(E1_FILIAL+E1_PREFIXO+E1_NUM) == SL1->( xFilial("SE1")+L1_SERIE+L1_DOC ))
	recLock("SE1",.F.)
	SE1->( dbDelete() )
	SE1->( msUnlock() )
	SE1->( dbSkip() )
end
EndIf
 
/*
If SL4->( dbSeek( SL1->( L1_FILIAL+L1_NUM ) ) )
while SL4->( !eof() .and. L4_FILIAL+L4_NUM == SL1->( L1_FILIAL+L1_NUM ) )
	if recLock("SL4",.F.)
		SL4->( dbDelete() )
		SL4->( msUnlock() )
	endif
	SL4->( dbSkip() )
end
EndIf

If SL2->( dbSeek( SL1->( L1_FILIAL+L1_NUM ) ) )
while SL2->( !eof() .and. L2_FILIAL+L2_NUM == SL1->( L1_FILIAL+L1_NUM ) )
	if recLock("SL2",.F.)
		SL2->( dbDelete() )
		SL2->( msUnlock() )
	endif
	SL2->( dbSkip() )
end
EndIf

if MH2->( dbSeek( SL1->( L1_FILIAL+L1_NUM ) ) )
    
   While MH2->(!EOF()) .And. MH2->(MH2_FILIAL+MH2_NUM) == SL1->(L1_FILIAL+L1_NUM)
	if recLock("MH2",.F.)
		MH2->( dbDelete() )
		MH2->( msUnlock() )
	endif
	MH2->( dbSkip() )
	End
end

//DbSelectArea("SZG")
SZG->(DbSetorder(3))
If SZG->(DbSeek(SL1->(L1_FILIAL+L1_KEYNFCE)))
if RecLock("SZG",.F.)
	SZG->( dbDelete() )
	SZG->( MsUnlock() )
endif
EndIf

if recLock("SL1",.F.)
	SL1->( dbDelete() )
	SL1->( msUnlock() )
endif

*/

Return( .T. )

