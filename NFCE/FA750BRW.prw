#INCLUDE "PROTHEUS.CH"

Static lFWCodFil := FindFunction("FWCodFil")
STATIC lNewIrBx	 := (FindFunction("FCALCIRBX") .AND. FindFunction("FGRVSFQIR"))
STATIC dDtMinPCC //necessario pois utiliza no FINA590.      
STATIC aSelFil	 := {}
Static lIsIssBx  := FindFunction("IsIssBx")
Static lIsEmpPub :=  FindFunction("IsEmpPub")

//----------------------------------------------------------------------------+
User Function FA750BRW()
Local aRotAdic := {}

aAdd(aRotAdic,{"Bordero Imp. Novo","U_XFina241",0,3})

Return( aRotAdic )      
//----------------------------------------------------------------------------+
User Function XFina241(cAlias, nReg, nOpc)
Local nOrdem    := 18 
Local lPanelFin := If(FindFunction("IsPanelFin"),IsPanelFin(),.F.)

Pergunte("F240BR",.F.)
//ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
// Parametros
//ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
// mv_par01		Considera Titulos ?	  			Normais / Adiantamentos
// mv_par02		Considera Filial ?  			(apenas Codebase)
// mv_par03		Da Filial ?						(apenas Codebase)
// mv_par04		Ate a Filial ?					(apenas Codebase)
// mv_par05		Marcar Titulos Automatic. ?
// mv_par06		Calculo dos Impostos ?			1-Vencimento Real           
// 			                                 	2-Geracao Bordero           
//												3-Ambas                     
// mv_par07		Mostra Lancamento ?  
// mv_par08		Seleciona Filiais ?				(apenas TOP)
//ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

PRIVATE cFil240
PRIVATE c240FilBT := Space(60)
Private aRotina   := MenuDef()
Private xConteudo

Private cLoteFin	:= Space(04)
Private cPadrao 	:= ""
Private cBenef		:= CriaVar("E5_BENEF")
Private nTotAGer 	:= 0
Private nTotADesp   := 0
Private nTotADesc   := 0
Private nTotAMul 	:= 0
Private nTotAJur 	:= 0
Private nValPadrao  := 0
Private nValEstrang := 0
Private cBanco   	:= CriaVar("E1_PORTADO")
Private cAgencia 	:= CriaVar("E1_AGEDEP")
Private cConta 	    := CriaVar("E1_CONTA")
Private cCtBaixa 	:= GetMv("MV_CTBAIXA")
Private cAgen240 	:= CriaVar("A6_AGENCIA")
Private cConta240	:= CriaVar("A6_NUMCON")
Private cModPgto    := CriaVar("EA_MODELO")
Private cTipoPag 	:= CriaVar("EA_TIPOPAG")
Private cMarca   	:= GetMark( )
Private cLote
Private cCadastro
Private aGetMark 	:= {}
Private nVlRetIrf	:= 0

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Procura o Lote do Financeiro                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
LoteCont( "FIN" )

dbSelectArea("SE2")
dbSetOrder(nOrdem)

FA241Borde("SE2", SE2->(Recno()), 3)	

dbSelectArea("SE2")
dbSetOrder(nOrdem)  && devolve ordem principal
If FunName()=="FINA590" .And. SE2->(FieldPos("E2_FILORIG")) > 0
	cFilOrig := SE2->E2_FILORIG
EndIf         

Return( Nil )