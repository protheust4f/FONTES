#INCLUDE "PROTHEUS.CH"
/*/
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  �LJ140EXC  � Autor � Alessandro Afonso  � Data �  28/05/07   ���
�������������������������������������������������������������������������͹��
���Descricao � Objetivo e estorno da baixa dos componentes da estrutura   ���
���          � produtos. Ponto de entrada do fonte LOJA140, Linha:544     ���
���          � Na exclus�o de Notas Fiscais.                              ���
�������������������������������������������������������������������������͹��
�������������������������������������������������������������������������͹��
���Uso       � CIE - Projeto:FS08003103                                   ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
/*/

User Function LJ140EXC()
Local aArea  := GetArea() 

If IsInCallStack("T4LOJE")
   RestArea(aArea)
   Return Nil  
EndIf   

  If EXISTBLOCK("CIEA060")
		U_CIEA060('ESTORNO',SL1->L1_NUM)
  Endif

RestArea(aArea)
Return Nil