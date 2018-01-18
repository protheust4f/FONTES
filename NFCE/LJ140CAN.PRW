#INCLUDE "PROTHEUS.CH"
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Programa  ³LJ140CAN	 | Autor ³ Fernando Fonseca      ³ Data ³18/04/2006  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Locacao   ³ Fabr.Tradicional  ³Contato ³ fernando.santos@microsiga.com.br ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Senha Superior para Cancelamento de Cupom Fiscal.		     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Aplicacao ³ SigaLoja                                                  	 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ CIE-EVENTOS: 		                                      	 ³±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
User Function Lj140CAN()

	Local lRet
	Local aArea := GetArea()
	
	Private cTitOper   := ""
	
	// Anderson em 30/06/2006 - Nao deixar usuario excluir orcamento caso tenha vindo da rotina de Postos de Venda (CIEA150)
	//If Alltrim(SL1->L1_ORIGEM) == "CIEA150"
	//	Aviso("ATENÇÃO","Não é poss;ivel a EXCLUSÃO de um Orçamento gerado pela rotina de Posto de Venda, verifique !",{"OK"})
	//	Return(.F.)
	//EndIf
	
	If IsInCallStack("T4LOJE")
	   RestArea(aArea)
	   Return Nil  
	EndIf   
	
	If Alltrim(SL1->L1_ORIGEM) == "LJ7002"
		DbSelectArea("PB1")
		DbSetOrder(3)
		If DbSeek(xFilial("PB1") +SL1->L1_COMANDA + SL1->L1_POSTO)
			Aviso("ATENÇÃO","Não é poss;ivel a EXCLUSÃO desta Venda pois a Comanda: " + SL1->L1_COMANDA + " do Posto de Venda: " + SL1->L1_POSTO + " deve ser EXCLUÍDA primeiro !",{"OK"})
			Return(.F.)
		EndIf
	EndIf
	
	cTitOper := "Digite a Senha do Superior!"
	lRet 	 := .T.//U_LjUserSup()
	
	// Anderson em 14/06/2007
	// Caso Possa excluir e a Origem do Orcamento foi a Rotina de Posto de Venda
	// devemos voltar o FLAG do Posto de Venda para 2 (Divergente - Marcio em 13/07/2006) e limpar o Numero do Orcamento
	If lRet .and. Alltrim(SL1->L1_ORIGEM) == "CIEA150"
	
		DbSelectArea("PB4")
		DbSetOrder(3) // Orcamento
		If DbSeek(xFilial("PB4")+SL1->L1_NUM)
		
			RecLock("PB4",.F.)
			PB4->PB4_STATUS := "2" // Divergente
			PB4->PB4_NUMORC := Space(6) // Limpando Numero do Orcamento que esta sendo cancelado neste momento         
			MsUnLock()
		
		EndIf
	
	EndIF
	
	RestArea(aArea)
	
Return ( lRet )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjUserSup ºAutor  ³Regiane R. Barreira º Data ³  08/05/06   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Informa a senha do usuario superior.		 	              º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ CIE		                                                  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
/*User Function LjUserSup()

	Local oGetSup
	Local oGetSenha
	Local oDlgSenha
	Local lRet		:= .F.
	Local cCaixaSup := Space( 15 )
	Local cSenhaSup := Space( 6 )
	Local cBitMap 	:= "LOGIN"
	Local cCaixaAtu := SubStr( cUsuario, 7, 15 )
	Local aArea 	:= GetArea()
	Local lDesc 	:= .F.
	Local nOpcA		:= 0 								//Botao confirmar
	Local nX       										//variavel contadora para Loop
	
	DEFINE DIALOG oDlgSenha TITLE "Autorizacao de superior: " + cTitOper FROM 20, 20 TO 225,310 PIXEL 
	
		@ 0, 0 BITMAP oBmp1 RESNAME cBitMap oF oDlgSenha SIZE 50,140 NOBORDER WHEN .F. PIXEL
	
		@ 05,55 SAY "Caixa Atual" PIXEL
		@ 15,55 MSGET cCaixaAtu WHEN .F. PIXEL SIZE 80,08
	
		@ 30,55 SAY "Caixa Superior" PIXEL
		@ 40,55 MSGET oGetSup VAR cCaixaSup WHEN aConfig()[4] PIXEL SIZE 80,08
	
		@ 55,55 SAY "Senha Superior" PIXEL
		@ 65,55 MSGET oGetSenha VAR cSenhaSup PASSWORD PIXEL SIZE 40,08 VALID P_VlSenhaSup( oGetSup, cCaixaSup, cSenhaSup )
	
		DEFINE SBUTTON FROM 85,75  TYPE 1 ACTION ( IIF( !lRet .OR. Empty(cSenhaSup), lRet := P_VlSenhaSup( oGetSup, cCaixaSup, cSenhaSup ), .T. ), oDlgSenha:End() ) ENABLE OF oDlgSenha
		DEFINE SBUTTON FROM 85,105 TYPE 2 ACTION { || lRet := .F., oDlgSenha:End() } ENABLE OF oDlgSenha
	
	ACTIVATE MSDIALOG oDlgSenha CENTERED ON INIT ( IIf( Type( "lUsaLeitor" ) == "L" .AND. lUsaLeitor, LeitorFoco( nHdlLeitor, .T. ), NIL ) )
	
	Return lRet
*/