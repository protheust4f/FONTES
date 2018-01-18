#INCLUDE "Topconn.ch"
#INCLUDE "Protheus.ch"

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  �TLOJR01   �Autor  �TOTALIT             � Data �  08/24/16   ���
�������������������������������������������������������������������������͹��
���Desc.     � Relatorio de log nota fiscais n�o localizadas              ���
���          �                                                            ���
�������������������������������������������������������������������������͹��
���Uso       � AP                                                        ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/



User Function TLOJR01()
//������������������������������������������Ŀ
//�Declaracao de variaveis                   �
//��������������������������������������������
Private oReport  := Nil
Private oSecCab	 := Nil
Private cPerg 	 := PadR ("TLOJR01", Len (SX1->X1_GRUPO))
//������������������������������������������Ŀ
//�Criacao e apresentacao das perguntas      �
//��������������������������������������������
PutSx1(cPerg,"01","Filial de?"  ,'','',"mv_ch1","C",TamSx3 ("ZZN_FILIAL")[1] ,0,,"G","","SM0","","","mv_par01","","","","","","","","","","","","","","","","")
PutSx1(cPerg,"02","Filial ate?" ,'','',"mv_ch2","C",TamSx3 ("ZZN_FILIAL")[1] ,0,,"G","","SM0","","","mv_par02","","","","","","","","","","","","","","","","")
PutSx1(cPerg,"03","Orcamento de?"  ,'','',"mv_ch3","C",TamSx3 ("ZZN_ORC")[1]    ,0,,"G","","","","","mv_par03","","","","","","","","","","","","","","","","")
PutSx1(cPerg,"04","Orcamento ate?" ,'','',"mv_ch4","C",TamSx3 ("ZZN_ORC")[1]    ,0,,"G","","","","","mv_par04","","","","","","","","","","","","","","","","")
PutSx1(cPerg,"05","Data de?"  ,'','',"mv_ch5","D",TamSx3 ("ZZN_DATA")[1]   ,0,,"G","","","","","mv_par05","","","","","","","","","","","","","","","","")
PutSx1(cPerg,"06","Data ate?" ,'','',"mv_ch6","D",TamSx3 ("ZZN_DATA")[1]   ,0,,"G","","","","","mv_par06","","","","","","","","","","","","","","","","")

//������������������������������������������Ŀ
//�Definicoes/preparacao para impressao      �
//��������������������������������������������
ReportDef()
oReport:PrintDialog()

Return Nil     

Static Function ReportDef()

oReport := TReport():New("TLOJR01","Log de Erros de Integra��o",cPerg,{|oReport| PrintReport(oReport)},"Impress�o do log de integra��o do XML com o Protheus.")
oReport:SetLandscape(.T.)

oSecCab := TRSection():New( oReport , "Log Integracao", {"QRY"} )
TRCell():New( oSecCab, "ZZN_FILIAL"  , "QRY")
TRCell():New( oSecCab, "ZZN_ORC"     , "QRY")
TRCell():New( oSecCab, "ZZN_DATA"    , "QRY")
TRCell():New( oSecCab, "ZZN_OBS"     , "QRY")

Return Nil


Static Function PrintReport(oReport)

Local cQuery     := ""

Pergunte(cPerg,.F.)

cQuery += " SELECT * FROM " + RetSqlName("ZZN") + " ZZN " + CRLF
cQuery += " WHERE ZZN.ZZN_FILIAL BETWEEN '" + mv_par01 + "' AND '" + mv_par02 + "' " + CRLF
cQuery += " AND ZZN.ZZN_ORC BETWEEN '" + mv_par03 + "' AND '" + mv_par04 + "' " + CRLF
cQuery += " AND ZZN.D_E_L_E_T_ = ' ' " + CRLF
cQuery := ChangeQuery(cQuery)

If Select("QRY") > 0
	Dbselectarea("QRY")
	QRY->(DbClosearea())
EndIf

TcQuery cQuery New Alias "QRY"

oSecCab:BeginQuery()
oSecCab:EndQuery({{"QRY"},cQuery})
oSecCab:Print()

Return Nil