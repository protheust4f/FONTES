#INCLUDE "PROTHEUS.CH"
#INCLUDE "TbiConn.ch"
#INCLUDE "Topconn.ch"

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
ฑฑษออออออออออัออออออออออหอออออออัออออออออออออออออออออหออออออัอออออออออออออปฑฑ
ฑฑบPrograma  ณLJFIMGRV  บAutor  ณ Thiago Rocco       บ Data ณ  25/08/16   บฑฑ
ฑฑฬออออออออออุออออออออออสอออออออฯออออออออออออออออออออสออออออฯอออออออออออออนฑฑ
ฑฑบDesc.     ณ Exclusใo de NF/ORC automatica atrav้s de agendamento       บฑฑ
ฑฑบ          ณ 									                          บฑฑ
ฑฑฬออออออออออุออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออนฑฑ
ฑฑบUso       ณ T4F                                                        บฑฑ
ฑฑศออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผฑฑ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿
*/

User Function T4LOJE1(aParam)

	Local nRegCan
	
	Local aArea
	
	Local cErrorBlock 
	
	Local dSTime
	Local cSTime
	Local cETime
	
	Local c__EmpAnt
	Local c__FilAnt

	Local cZZNFilial
	
	Local bErrorBlock
	Local oErrorBlock 
	Local bFRTExclusa  
	
	Local lRPCSet
	Local lRPCReSet
	
	nRegCan := 0
	
	bErrorBlock:=ErrorBlock()
	bFRTExclusa:={|e|oErrorBlock:=e,break(oErrorBlock)}
	
	dSTime:=MsDate()
	cSTime:=Time()  
	
	Conout("","==================================================================================","") 
	
	ConOut("","[BEGIN PROCESS: ]"+ProcName()+"["+DtoC(dSTime)+"]["+cSTime+"]","")
	
	Conout("","==================================================================================","")
	
	lRPCSet:=IsinCallstack("T4LOJE")
	lRPCSet:=(lRPCSet.or.(!(Type("cEmpAnt")=="C").or.!(Type("cFilAnt")=="C")))
	
	If (lRPCSet)
		lRPCReSet:=(lRPCSet.and.((Type("cEmpAnt")=="C").and.(Type("cFilAnt")=="C")))
		if (lRPCReSet)
			c__EmpAnt:=cEmpAnt
			c__FilAnt:=cFilAnt
			aArea:=GetArea()
	    endif
	   RpcSetType(3)
	   VarInfo("Parametros passado pela Rotina: [aParam]",aParam)
	   RPCSetEnv(aParam[01],aParam[02])
	EndIf          
	
	cZZNFilial:=xFilial("ZZN")
	
	//Efetuou a Query na SZG para capturar todos os Or็amento que possuem XML come็ando com AC, al้m disso status = 1 = Sucesso.

   cQuery := "SELECT L1.L1_NUM"
   cQuery += "      ,ZG.ZG_ARQUIVO"
   cQuery += "      ,L1.L1_DOC"
   cQuery += "      ,L1.L1_SERIE" 
   cQuery += "  FROM "+RetSQlName("SZG")+" ZG "
   cQuery += " INNER JOIN "+RetSQlName("SL1")+" L1"
   cQuery += "    ON L1.L1_KEYNFCE=SUBSTR(ZG.ZG_ARQUIVO,1,44)"  
   cQuery += " WHERE SUBSTR(ZG.ZG_ARQUIVO,53,13)='PROCEVENTONFE'"
   cQuery += "   AND ZG.D_E_L_E_T_<>'*'"
   cQuery += "   AND L1.D_E_L_E_T_<>'*'"
   cQuery += "   AND ZG.ZG_STATUS IN ('1','2')"
   cQuery += " UNION "
   cQuery += " SELECT L1.L1_NUM"
   cQuery += "       ,ZG.ZG_ARQUIVO"
   cQuery += "       ,L1.L1_DOC"
   cQuery += "       ,L1.L1_SERIE FROM "+RetSQlName("SZG")+" ZG"
   cQuery += "  INNER JOIN "+RetSQlName("SL1")+" L1"
   cQuery += "     ON L1.L1_KEYNFCE=SUBSTR(ZG.ZG_ARQUIVO,3,44)"
   cQuery += "  WHERE SUBSTR(ZG.ZG_ARQUIVO,1,2)='AC'"
   cQuery += "    AND ZG.D_E_L_E_T_<>'*'"
   cQuery += "    AND L1.D_E_L_E_T_<>'*'"
   cQuery += "    AND ZG.ZG_STATUS IN ('1','2')" 

	If SELECT("QRY") > 0
		QRY->(DbCloseArea())
	Endif
	
	TcQuery cQuery Alias "QRY" New
	DbSelectArea("QRY")
	QRY->(DBGotop())
	
	DbSelectArea("ZZN")
	ZZN->(DbSetOrder(1))
	While QRY->(!Eof())
	    Conout("","Nro do Orcamento 1: "+QRY->L1_NUM,"")  
	    cErrorBlock:="UNNDEFINED ERROR"
	    nRegCan:=(-1)
	    ErrorBlock(bFRTExclusa)
	    begin sequence    	
			//Fun็ใo que realiza a exclusใo de NF/ORC padrใo do sistema.
	    	nRegCan:=FRTExclusa(Alltrim(QRY->L1_NUM))
	    recover	
	    	DEFAULT:=nRegCan:=(-1)
	    	if (ValType(oErrorBlock)=="O")
	    		cErrorBlock:=oErrorBlock:Description
	    		cErrorBlock+=oErrorBlock:ErrorStack
	    		ApMsgAlert(cErrorBlock)
	    	endif
	    	if .not.(Empt(cErrorBlock))
	    		ConOut("","[STACK: ]"+ProcName()+"[HASERROR]","[ERROR: ]"+cErrorBlock,"")
	    		cErrorBlock:=""
	    	endif
	    end sequence
	    ErrorBlock(bErrorBlock)
	    Conout("----------------------------------------------------------------------------------")  
	    Conout("","Nro do Orcamento 2 : "+QRY->L1_NUM,"")  
	    Conout("Retorna da Funcao: "+Str(nRegCan))
	    Conout("----------------------------------------------------------------------------------")  
	    
		If nRegCan == 1
			//Efetuar Grava็ใo na ZZN - Log de Erro de Integra็ใo , 1 = Nใo conseguu excluir a NF
			If !DbSeek(cZZNFilial+ZZN->ZZN_ORC)
				ZZN->(Reclock("ZZN",.T.))
				ZZN->ZZN_FILIAL := cZZNFilial
				ZZN->ZZN_ORC    := QRY->L1_NUM
				ZZN->ZZN_DATA   := dDataBase
				ZZN->ZZN_OBS    := "Nใo foi possํvel localizar o registro SF2 para o Doc: "+Alltrim(QRY->L1_DOC)+" - Serie: "+Alltrim(QRY->L1_SERIE)+"."
				ZZN->(MsUnlock())
			Endif
		Elseif nRegCan == 2
			//Efetuar Grava็ใo na ZZN - Log de Erro de Integra็ใo, 2 = Or็amento nใo encontrado
			If !DbSeek(cZZNFilial+ZZN->ZZN_ORC)
				ZZN->(Reclock("ZZN",.T.))
				ZZN->ZZN_FILIAL := cZZNFilial
				ZZN->ZZN_ORC    := QRY->L1_NUM
				ZZN->ZZN_DATA   := dDataBase
				ZZN->ZZN_OBS    := "Orcamento"+QRY->L1_NUM+" nao encontrado"
				ZZN->(MsUnlock())
			Endif
		Else //Excluido com sucesso
			Conout("","[T4FLE - EXCLUSรO DE NF/ORC] - Orc: "+Alltrim(QRY->L1_NUM)+" Executado com Sucesso","")
			//Efetuar Grava็ใo do Status na SZG para 3 = Cancelado com Sucesso
			cUpd := "UPDATE "+ RetSqlName("SZG") +" SET ZG_STATUS = '3' WHERE D_E_L_E_T_<>'*' and ZG_ARQUIVO = '"+QRY->ZG_ARQUIVO+"'"
			nError := TCSQLExec(cUpd)
			
			If nError!=0
				Conout("","[ERRO SZG] - "+tcSQLError(),"")
				nError := 0
			Endif
		Endif
		QRY->(DbSkip())
	EndDo
	
	If SELECT("QRY") > 0
		QRY->(DbCloseArea())
	Endif
	
	If (lRPCSet)
		RpcClearEnv()
		if (lRPCReSet)
		   RpcSetType(3)
		   RPCSetEnv(c__EmpAnt,c__FilAnt)	
		   RestArea(aArea)
		endif
	endif
	
	aSize(aParam,0)
	aParam:=NIL
	
	dETime:=Date()
	cETime:=Time()
	
	Conout("","==================================================================================","")
	
	ConOut("","[END PROCESS: ]"+ProcName()+"["+DtoC(dETime)+"]["+cETime+"]["+ElapTime(cSTime,cETime)+"]","")
	
	Conout("","==================================================================================","")

Return
                                
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
ฑฑษออออออออออัออออออออออหอออออออัออออออออออออออออออออหออออออัอออออออออออออปฑฑ
ฑฑบPrograma  ณAIMPCFE   บAutor  ณMicrosiga           บ Data ณ  07/23/16   บฑฑ
ฑฑฬออออออออออุออออออออออสอออออออฯออออออออออออออออออออสออออออฯอออออออออออออนฑฑ
ฑฑบDesc.     ณ                                                            บฑฑ
ฑฑบ          ณ                                                            บฑฑ
ฑฑฬออออออออออุออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออนฑฑ
ฑฑบUso       ณ AP                                                        บฑฑ
ฑฑศออออออออออฯออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผฑฑ
ฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑฑ
฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿฿
*/
user function T4LOJE(pEmp,pFilial) 

	Local aArea
	Local aParam
	
	aArea:=GetArea()
	
	aParam:={pEmp,pFilial,1}
	
	T4LOJE(@aParam)
	
	RestArea(aArea)
	
Return(NIL)

Static function T4LOJE(aParam) 
Return(U_T4LOJE1(@aParam))

user function T4LOJE20() 

	Local aParam
	
	Local pEmp
	Local pFilial
	
	pEmp:="20"
	pFilial:="01"
	
	aParam:={pEmp,pFilial}

Return(T4LOJE(@aParam))
