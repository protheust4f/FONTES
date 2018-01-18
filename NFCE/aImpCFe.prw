#include "totvs.ch"
#include "fileio.ch"                                  

#xtranslate NToS([<n,...>])=>LTrim(Str([<n>]))

// Define se está rodando em ambiente de testes
#define baseTeste   "X"$getEnvServer()
#ifndef CRLF
    #define CRLF    chr(13)+chr(10)
#endif
// Nome do arquivo de log para debug
#define __debugFile         getNewPar("ES_CFEDIRE","\integracao\cfe\erros\_debug_"+DToS(MsDate())+"_"+StrTran(Time(),":","_")+".log")
// Caminho para encontrar os XMLs
#define __filePath          getNewPar("ES_CFEDIR" ,"\integracao\cfe\")
// Mascara para encontrar os XMLs pelo CNPJ da filial corrente
#define __fileMask          getNewPar("ES_CFEDIR" ,"\integracao\cfe\")+"*"+SM0->M0_CGC+"*.xml"
// Caminho para mover os XMLs lidos com sucesso
#define __lidosPath         getNewPar("ES_CFEDIRL","\integracao\cfe\lidos\"+AllTrim(SM0->M0_CODFIL)+"\")
// Caminho para mover os XMLs com erro na leitura
#define __errosPath         getNewPar("ES_CFEDIRE","\integracao\cfe\erros\"+AllTrim(SM0->M0_CODFIL)+"\")
// Caminho para mover os XMLs descartados
#define __descaPath         getNewPar("ES_CFEDIRD","\integracao\cfe\descartados\"+AllTrim(SM0->M0_CODFIL)+"\")
// Quantidade de arquivos cada thread deve processar (usado para calcular quantas threads subir)
#define __filesPerThread    max(1,getNewPar("ES_CFEAPT",100))
// Semaforo de lock da job principal,para evitar duas instâncias conflitando na mesma empresa
#define __lckEmp            "aImpCFeEMP"+cEmpAnt
// Semaforo de lock das jobs de gerenciamento das filiais
#define __lckFil            "aImpCFeFIL"+cEmpAnt+cFilAnt
// Chave de chamada das jobs via IPC para executarem a leitura dos XML
#define __ipcKey            "aImpCFeFIL"+cEmpAnt+cFilAnt
// Semaforo de lock das jobs de processamento
#define __lckJob            "aImpCFeJOB"+cEmpAnt+cFilAnt+strZero(nThread,4)
// Nome dos arquivos de controle de killSession
#define __killFileName      "\semaforo\aImpCFe."+strZero(threadID(),6)

// Define o Conjunto de Caracteres a serem removidos no Incicio do XML
#define S_239_187_191       (CHR(239)+CHR(187)+CHR(191))

// Define o Tipo de Consumo da Conexao RPC
#define RPC_TYPE            3

static aTES
static aFormas:=;
{;
    {"01","R$"},; // Dinheiro
    {"02","CH"},; // Cheque
    {"03","CC"},; // Cartão de Crédito
    {"04","CD"},; // Cartão de Débito
    {"05","CR"},; // Crédito Loja
    {"10","VA"},; // Vale Alimentação
    {"11","VA"},; // Vale Refeição
    {"12","VP"},; // Vale Presente
    {"13","VA"},; // Vale Combustível
    {"99","CR"};  // Outros
}

static cCliPad
static cTESPad
static cLojaPad
static cVendPad

static s239187191

static nTamDoc
static nTamItem
static nTamProd

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:aImpCFe
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Job principal da importação de XML de CFe para o Protheus.
                   Somente este será chamado pelo [OnStart] no ini do servidor
                   Deve ser chamado 1 por empresa,pois disparará as jobs de
                   todas as filiais apenas da empresa onde foi configurado.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
user function aImpCFe(cEmp,cFil,nMaxThreads,nLifeTime,nTimeOut)

    local aSlaves

    local cEnv
    local c_EmpAnt
    local c_FilAnt

    local lEmpAnt
    local lFilAnt
    local lEmpFil

    local lRPCSet
    local lRPCClean

    local lRunLocal

    local i

    local nTry
    local nSec
    local nSlave
    local nStart
    
    local nSZGOrder2

    local oServer

    local cdebugFile

    nStart:=Seconds()
    aSlaves:=Array(0)
    nSlave:=1

    DEFAULT cEmp:="20" //"99"
    DEFAULT cFil:="01"

    // 10 threads de processamento de XML (cada filial)
    DEFAULT nMaxThreads:=10
    // 1 hora antes das threads finalizarem para liberar memória e serem substituídas por novas.
    // aplicavel a todas as jobs,tanto a master,quanto as das filiais e as de processamento dos XML.
    // no nLifeTime,cada instância recebe alguns segundos a mais umas das outras,para não caírem e subirem todas juntas
    DEFAULT nLifeTime:=(60*60)

    // 2 minutos até as threads de processamento de XML abandonarem por ociosidade.
    // nos momentos de pico é provável que sejam muitas,depois algumas cairão automaticamente e sob demanda sobem novas
    DEFAULT nTimeOut:=(60*2)

    lEmpAnt:=(Type("cEmpAnt")=="C")
    lFilAnt:=(Type("cFilAnt")=="C")
    lEmpFil:=((lEmpAnt).and.(lFilAnt))
    if (lEmpAnt).and.(lFilAnt)
        c_EmpAnt:=cEmpAnt
        c_FilAnt:=cFilAnt
        lRPCClean:=.F.
    else
        lRPCClean:=.T.
    endif
    lRPCSet:=(!(lEmpFil).or.!(cEmpAnt==cEmp).or.!(cFilAnt==cFil))

    //prepare enviroment
    if (lRPCSet)
        rpcSetType(RPC_TYPE)
        rpcSetEnv(cEmp,cFil)
    endif

    ConOut("[aImpCFe]-INICIO-Empresa: "+cEmp+" Filial: "+cFil)

    // Semaforo para existir apenas uma instância deste job para cada empresa
    if !lockByName(__lckEmp,.T.,.T.)
        if (lRPCSet)
            if ((lEmpAnt).or.(lFilAnt))
                rpcSetType(RPC_TYPE)
                rpcSetEnv(c_EmpAnt,c_FilAnt)
            endif
            if (lRPCClean)
                rpcClearEnv()
            endif
        endif
        return
    endif

    if !setKillF()
        return
    endif

    if (baseTeste)
        cdebugFile:=getdebugFile()
        if file(cdebugFile)
            fErase(cdebugFile)
        endif
    endIf

    //as variaveis estao vindo do ini como caracter
    nLifeTime:=if(ValType(nLifeTime)=="C",val(nLifeTime),nLifeTime)
    nMaxThreads:=if(ValType(nMaxThreads)=="C",val(nMaxThreads),nMaxThreads)
    nTimeOut:=if(ValType(nTimeOut)=="C",val(nTimeOut),nTimeOut)

    cSZGFilial:=xFilial("SZG")
    nSZGOrder2:=RetOrder("SZG","ZG_FILIAL+ZG_STATUS+ZG_ARQUIVO")

    while !isKilled().and.!timeToGo(nStart,nLifeTime)

        cEnv:=getEnvServer()
        aSlaves:=loadSlaves()
        nSlave:=if(nSlave>len(aSlaves),1,nSlave)
        lRunLocal:=empty(aSlaves)

        // identifica quais filiais utilizam SATCFe
        aFilSAT:=loadFilSAT()
        ConOut("[aImpCFe]-FILIAIS SAT: "+NToS(LEN(afilSAT)))
        i:=1

        //funcao que copia os arquivos do servidor de origem
        ConOut("[aImpCFe]-INICIO COPIA FTP")
        getXMLFile("AFTER")
        ConOut("[aImpCFe]-FIM COPIA FTP")

        SM0->(dbSetOrder(1))
        while !isKilled().and.i<=len(aFilSAT)
            if SM0->(dbSeek(cEmpAnt+aFilSAT[i]))
                cFilAnt:=SM0->M0_CODFIL
                ConOut("[aImpCFe]-FILIAL: "+cFilAnt)
                SZG->(dbSetOrder(nSZGOrder2))
                // Testo se ha uma thread de gerenciamento de filial rodando
                if (!empty(directory(__fileMask)).or.SZG->(dbSeek(cSZGFilial+"0"))).and.lockByName(__lckFil,.T.,.T.)
                    // Libero o bloqueio,porque a propria thread terá que manter bloqueada para se provar viva
                    unlockByName(__lckFil,.T.,.T.)
                    if !lRunLocal
                        nTry:=0
                        oServer:=TRPC():new(cEnv)
                        while !oServer:connect(aSlaves[nSlave,1],aSlaves[nSlave,2]).and.(nTry<=len(aSlaves))
                            dbgOut("Nao foi possivel se conectar ao slave "+strZero(nSlave,3)+"-"+aSlaves[nSlave][1]+":"+aSlaves[nSlave][2])
                            nTry++
                            nSlave:=if(nSlave==len(aSlaves),1,nSlave+1)
                        end
                        if (nTry>len(aSlaves))
                            lRunLocal:=.T.
                        else
                            dbgOut("Job da filial "+cFilAnt+" iniciada no slave "+strZero(nSlave,3))
                            oServer:callProc("rpcSetType",RPC_TYPE)
                            oServer:callProc("startJob","u_aImpCFeF",cEnv,.F.,cEmpAnt,cFilAnt,nMaxThreads,nLifeTime+(nSlave*3),nTimeOut)
                            nSlave:=if(nSlave==len(aSlaves),1,nSlave+1)
                        endIf
                        oServer:disconnect()
                    endIf

                    if lRunLocal
                        dbgOut("Job da filial "+cFilAnt+" iniciada localmente")
                        startJob("u_aImpCFeF",cEnv,.F.,cEmpAnt,cFilAnt,nMaxThreads,nLifeTime+(nSlave*3),nTimeOut)
                    endIf
                endif
            endif

            i++

        end while

        // aguarda 30 segundos pra verificar tudo de novo
        // deixando em 30 segundos porque esta thread é apenas de manutenção dos serviços no ar,não processa de fato muita coisa
        nSec:=0
        while !isKilled().and.(nSec++<30)
            sleep(1000)
        end while
    end while

    dbgOut("Job principal finalizada por LifeTime ou KillApp")

    unlockByName(__lckEmp,.T.,.T.)
    unlockByName(__killFileName,.T.,.T.)
    fErase(__killFileName)

    if (lRPCSet)
        if ((lEmpAnt).or.(lFilAnt))
            rpcSetType(RPC_TYPE)
            rpcSetEnv(c_EmpAnt,c_FilAnt)
        endif
        if (lRPCClean)
            rpcClearEnv()
        endif
    endif

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:aImpCFeF
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Job gerenciador de importacao de XML instanciado para cada
                   filial do sistema,disparado pela aImpCFe()i configurado.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
user function aImpCFeF(cEmp,cFil,nMaxThreads,nLifeTime,nTimeOut)

    local aFila
    local aFiles

    local bError
    local bErrorBlock

    local c_EmpAnt
    local c_FilAnt

    local cXML
    local cPath
    local cSZGLock
    local cFileName
    local cSZGFilial

    local lEmpAnt
    local lFilAnt
    local lEmpFil

    local lRPCSet
    local lRPCClean

    local lSZGLock

    local nSec
    local nFree
    local nIdle
    local nStart
    local nFile
    local nFiles
    local nThreads
    
    local nSZGOrder1

    aFila:={Array(0),(-1),0}

    nIdle:=(-1)
    nStart:=Seconds()

    // 10 threads de processamento de XML (cada filial)
    DEFAULT nMaxThreads:=10
    // 1 hora antes das threads finalizarem para liberar memória e serem substituídas por novas.
    // aplicavel a todas as jobs,tanto a master,quanto as das filiais e as de processamento dos XML.
    // no nLifeTime,cada instância recebe alguns segundos a mais umas das outras,para não caírem e subirem todas juntas
    DEFAULT nLifeTime:=(60*60)

    // 2 minutos até as threads de processamento de XML abandonarem por ociosidade.
    // nos momentos de pico é provável que sejam muitas,depois algumas cairão automaticamente e sob demanda sobem novas
    DEFAULT nTimeOut:=(60*2)

    lEmpAnt:=(Type("cEmpAnt")=="C")
    lFilAnt:=(Type("cFilAnt")=="C")
    lEmpFil:=((lEmpAnt).and.(lFilAnt))
    if (lEmpAnt).and.(lFilAnt)
        c_EmpAnt:=cEmpAnt
        c_FilAnt:=cFilAnt
        lRPCClean:=.F.
    else
        lRPCClean:=.T.
    endif
    lRPCSet:=(!(lEmpFil).or.!(cEmpAnt==cEmp).or.!(cFilAnt==cFil))

    if (lRPCSet)
        rpcSetType(RPC_TYPE)
        rpcSetEnv(cEmp,cFil)
    endif

    ConOut("[aImpCFe-aImpCFeF]-Empresa: "+cEmp+" FILIAL: "+cFil)

    // Semaforo para existir apenas uma instância deste job para cada empresa e filial
    if !lockByName(__lckFil,.T.,.T.)
        if (lRPCSet)
            if ((lEmpAnt).or.(lFilAnt))
                rpcSetType(RPC_TYPE)
                rpcSetEnv(c_EmpAnt,c_FilAnt)
            endif
            if (lRPCClean)
                rpcClearEnv()
            endif
        endif
        return
    endif

    setKillF()
    cPath:=__filePath
    // garante a existencia do diretorio
    makeDir(__lidosPath)
    // garante a existencia do diretorio
    makeDir(__errosPath)
    // garante a existencia do diretorio
    makeDir(__descaPath)

    // cancela tratamento de erro para evitar quedas do job
    bError:={|e|.T.}
    bErrorBlock:=errorBlock(bError)

    // tabela de XMLs importados
    dbSelectArea("SZG")
    cSZGFilial:=xFilial("SZG")
    nSZGOrder1:=RetOrder("SZG","ZG_FILIAL+ZG_ARQUIVO")

    while !isKilled().and.!timeToGo(nStart,nLifeTime)

        aFiles:=directory(__fileMask)
        nFiles:=(Len(aFiles))
        ConOut("[aImpCFe-aImpCFeF]-Qtde XML´s: "+NToS(nFiles))

        if (nFiles>0)

            dbgOut("Job da filial "+cFilAnt+" encontrou "+NToS(nFiles)+" arquivos na pasta")

            // calcula quantas threads precisa neste momento
            nThreads:=(nFiles/__filesPerThread)
            // arredonda o numero de threads sempre para cima
            nThreads+=if(nThreads>int(nThreads),1,0)

            // Conta quantas threads livres há no momento
            nFree:=ipcCount(__ipcKey)
            // limita o numero de threads,caso exceda o configurado como máximo
            nThreads:=min(nMaxThreads,int(nThreads)-nFree)

            if nThreads>0
                // solicita o start das threads necessárias
                newThreads(nThreads,nMaxThreads,nLifeTime,nTimeOut)
            endIf

            SZG->(dbSetOrder(nSZGOrder1))

            // inicia a gravação dos XML no SZG e distribui pelas threads
            for nFile:=1 to nFiles

                cFileName:=aFiles[nFile][1]

                // Se o arquivo sumiu de repente,é porque outra instância o moveu. Tudo bem,é só ignora-lo
                if (!file(cPath+cFileName))
                    loop
                endif
                
                cSZGLock:=FileNoExt(cFileName)
        		lSZGLock:=lockByName(cSZGLock,.T.,.T.)
                
                // Se não conseguiu o lock é porque outra instância o obteve. Tudo bem,é só ignora-lo
                if !(lSZGLock)
                    loop
                endif                

                ConOut("[aImpCFe-aImpCFeF]-ReadXML: "+cPath+cFileName)
                cXML:=readXML(cPath+cFileName)

                // Corrige o inicio de alguns arquivos que vêm com o XML corrompido sempre na mesma forma.
                if SubStr(cXML,1,78)=="×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u×]u.06"
                    if "<CFe><infCFe"$cXML
                        cXML:="<CFe><infCFe Id='CFe"+SubStr(cFileName,4,44)+"' versao='0.06'"+SubStr(cXML,80)
                    endif
                endif

                DEFAULT s239187191:=S_239_187_191
                if (SubStr(CXML,1,3)==s239187191)
                    cXML:=SubStr(cXML,4)
                endif

                if SZG->(dbSeek(cSZGFilial+cFileName)).and.!limpaBase()
                    // Arquivo já importado com sucesso
                    if (SZG->ZG_STATUS$"3"/*"0;1;3"*/)
                        moveToDesc(cFileName)
                        unlockByName(cSZGLock,.T.,.T.)
                        loop
                    else
                        // Arquivo com erro e que foi novamente copiado para a pasta,vai tentar de novo
                        lSZGLock:=recLock("SZG",.F.)
                        if (lSZGLock)
                            SZG->ZG_ERRO:=" "
                            SZG->ZG_STATUS:="0"
                        endif
                    endif
                else
                    lSZGLock:=recLock("SZG",.T.)
                    if (lSZGLock)
                        ConOut("[aImpCFe-aImpCFeF]-gravação SZG -> ZG_ARQUIVO: "+cFileName)
                        SZG->ZG_FILIAL:=cSZGFilial
                        SZG->ZG_ARQUIVO:=cFileName
                    endif
                endif

                if (lSZGLock)
                    if empty(cXML)
                        cXML:=" "
                    endif
                    SZG->ZG_XML:=cXML
                endif

                if empty(cXML)
                    if (lSZGLock)
                        SZG->ZG_STATUS:="2"
                        SZG->ZG_ERRO:="Arquivo vazio"
                    endif
                    moveToErro(cFileName)
                else
                    if (lSZGLock)
                        SZG->ZG_STATUS:="0"
                    endif
                endif

                if (lSZGLock)
                    SZG->(msUnlock())
                endif

                moveToLido(cFileName)

				unlockByName(cSZGLock,.T.,.T.)

                aAdd(aFila[1],cFileName)
                aFila:=checkFila(aFila,nMaxThreads,nLifeTime,nTimeOut)

            next nFile

            nIdle:=(-1)

        elseIf (nIdle<0)

            nIdle:=Seconds()

        elseIf timeToGo(nIdle,nTimeOut)

            dbgOut("Job da filial "+cFilAnt+" abandonando por ociosidade (TimeOut)")
            exit

        endIf

        // aguarda 10 segundos verificando fila para então verificar novamente se há novos arquivos
        nSec:=1
        while !isKilled().and.(nSec<=10)
            // se a fila está vazia
            if empty(aFila[1])
                // pega um dos intervalos de checagem e procura registros que ficaram pendentes na SZG
                if (nSec==1)
                    // podem ter ficado órfãos de threads derrubadas,por exemplo
                    aFila[1]:=loadFila()
                endif
            else
                aFila:=checkFila(aFila,nMaxThreads,nLifeTime,nTimeOut)
                nIdle:=(-1)
            endif
            nSec++
            sleep(1000)
        end while

    end while

    unlockByName(__lckFil,.T.,.T.)
    unlockByName(__killFileName,.T.,.T.)
    fErase(__killFileName)

    if (lRPCSet)
        if ((lEmpAnt).or.(lFilAnt))
            rpcSetType(RPC_TYPE)
            rpcSetEnv(c_EmpAnt,c_FilAnt)
        endif
        if (lRPCClean)
            rpcClearEnv()
        endif
    endif

    errorBlock(bErrorBlock)

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:checkFila
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Job gerenciador de importacao de XML instanciado para cada
                   filial do sistema,disparado pela aImpCFe()i configurado.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function checkFila(aFila,nMaxThreads,nLifeTime,nTimeOut)

    local nThreads
    local nAtivas

    while !isKilled().and.!empty(aFila[1])
        if ipcGo(__ipcKey,aFila[1][1])
            aDel(aFila[1],1)
            aSize(aFila[1],len(aFila[1])-1)
            // se a fila diminuiu desde a última passagem de trabalho
            if aFila[3]>len(aFila[1])
                // zera o cronometro de gargalo da fila
                aFila[2]:=(-1)
            endif
        else
            If aFila[2]<0
                // começa o cronometro de gargalo caso esteja zerado
                aFila[2]:=Seconds()
                // anota quantos processos ha na fila no começo do gargalo
                aFila[3]:=len(aFila[1])
            endif
            exit
        endif
    end while

    if !isKilled().and.(aFila[2]>=0)
        nAtivas:=countJobs(nMaxThreads)

        if ((nAtivas==0).or.(timeToGo(aFila[2],5)))

            ConOut("Job da filial "+cFilAnt+" fila "+NToS(int(len(aFila)))+"  ("+NToS(__filesPerThread)+" arquivos na fila)")

            // calcula quantas threads precisa neste momento
            nThreads:=len(aFila[1])/__filesPerThread
            // arredonda o numero de threads sempre para cima
            nThreads+=if(nThreads>int(nThreads),1,0)
            // limita o numero de threads,caso exceda o configurado como máximo
            nThreads:=min(nMaxThreads,int(nThreads)-nAtivas)

            if (nThreads>0)
                ConOut("Job da filial "+cFilAnt+" pediu "+NToS(int(nThreads))+" novas threads por gargalo ("+NToS(len(aFila[1]))+" arquivos na fila)")
                // solicita o start das threads necessárias
                newThreads(nThreads,nMaxThreads,nLifeTime,nTimeOut)
            else
                ConOut("Job da filial "+cFilAnt+" nao achou necessario solicitar mais threads e ha "+NToS(nAtivas)+" threads ativas para a filial")
            endIf
            aFila[2]:=(-1)
        endIf
    endif

return aFila

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:loadFila
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Busca na SZG arquivos que tenham ficado sem processar por
                   quaisquer motivos e os readiciona à fila de distribuicao
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function loadFila()

    local aRet:=Array(0)
    local cQry:=getNextAlias()

    beginSQL alias cQry
        SELECT SZG.ZG_ARQUIVO
          FROM %table:SZG% SZG
         WHERE SZG.%NotDel%
           AND SZG.ZG_FILIAL=%xFilial:SZG%
           AND SZG.ZG_STATUS='0'
    endSQL

    while (cQry)->(!eof())
        aAdd(aRet,(cQry)->ZG_ARQUIVO)
        (cQry)->(dbSkip())
    end while

    (cQry)->(dbCloseArea())
    dbSelectArea("SZG")
    ConOut("Verificação de fila encontrou "+NToS(len(aRet))+" arquivos pendentes.")

return aRet

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:aImpCFeJ
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Job que le efetivamente os XML que lhe foram designados
                   e importa para o banco de dados.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
user function aImpCFeJ(cEmp,cFil,nThread,nLifeTime,nTimeOut)

    local bError
    local bErrorBlock

    local cErro
    local cFileName

    local c_EmpAnt
    local c_FilAnt

    local cSZGLock
    local cSZGFilial

    local lEmpAnt
    local lFilAnt
    local lEmpFil

    local lRPCSet
    local lRPCClean
    
    local lSZGFound

    local nTry
    local nIni
    local nFim
    local nStart
    
    local nSZGOrder2

    local lSZGLock
    local lZGEMISSAO
    local limportXML

    nStart:=Seconds()

    lEmpAnt:=(Type("cEmpAnt")=="C")
    lFilAnt:=(Type("cFilAnt")=="C")
    lEmpFil:=((lEmpAnt).and.(lFilAnt))
    if (lEmpAnt).and.(lFilAnt)
        c_EmpAnt:=cEmpAnt
        c_FilAnt:=cFilAnt
        lRPCClean:=.F.
    else
        lRPCClean:=.T.
    endif
    lRPCSet:=(!(lEmpFil).or.!(cEmpAnt==cEmp).or.!(cFilAnt==cFil))

    if (lRPCSet)
        rpcSetType(RPC_TYPE)
        rpcSetEnv(cEmp,cFil,,,"LOJA")
    endif

    // verifica se não existe outra thread com o mesmo ID e abandona
    if !lockByName(__lckJob,.T.,.T.)
        if (lRPCSet)
            if ((lEmpAnt).or.(lFilAnt))
                rpcSetType(RPC_TYPE)
                rpcSetEnv(c_EmpAnt,c_FilAnt)
            endif
            if (lRPCClean)
                rpcClearEnv()
            endif
        endif
        return
    endIf

    setKillF()
    bError:={|e|.T.}
    bErrorBlock:=errorBlock(bError)

    cCliPad:=getMV("MV_CLIPAD")
    cTESPad:=getNewPar("ES_TESSPRO","501")
    cLojaPad:=getMV("MV_LOJAPAD")
    cVendPad:=getMV("MV_VENDPAD")

    nTamDoc:=GetSX3Cache("L1_DOC","X3_TAMANHO")
    nTamItem:=GetSX3Cache("L2_ITEM","X3_TAMANHO")
    nTamProd:=GetSX3Cache("B1_COD","X3_TAMANHO")

    aTES:=Array(0)

    lZGEMISSAO:=SZG->(FieldPos("ZG_EMISSAO")>0)
    cSZGFilial:=xFilial("SZG")
	nSZGOrder2:=RetOrder("SZG","ZG_FILIAL+ZG_STATUS+ZG_ARQUIVO")

    SZG->(dbSetOrder(nSZGOrder2))
    
    while !isKilled().and.!timeToGo(nStart,nLifeTime)

        cFileName:=""
        nTry:=0
        // espera de 2 em 2 segundos,para não perder chamadas com intervalos muito curtos
        while !isKilled().and.!ipcWaitEx(__ipcKey,2000,@cFileName).and.(nTry<nTimeOut)
            nTry+=2
            if mod(nTry,10)==0
                dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" aguardando trabalho ha "+NToS(nTry)+" segundos")
            endif
        end while

        if isKilled().or.(nTry>=nTimeOut)
            dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" abandonou por timeout ou killApp")
            exit
        endif

        cSZGLock:=FileNoExt(cFileName)
        
        lSZGLock:=lockByName(cSZGLock,.T.,.T.)
        
        lSZGFound:=((lSZGLock).and.(SZG->(dbSeek(cSZGFilial+"0"+cFileName))))
        if .not.(lSZGFound)
        	lSZGLock:=lockByName(cSZGLock,.T.,.T.)
        	lSZGFound:=lSZGFound:=((lSZGLock).and.(SZG->(dbSeek(cSZGFilial+"1"+cFileName))))
        endif
        
        if (lSZGFound)
            if (lSZGLock)
                lSZGLock:=recLock("SZG",.F.)
            else
                UnlockByName(cSZGLock,.T.,.T.)
            endif
            if (lSZGLock)
                if .not.(SZG->ZG_STATUS=="3")
                    SZG->ZG_STATUS:="1"
                    SZG->(MsUnLock())
                    lSZGLock:=recLock("SZG",.F.)
                endif
            endif
            if (lSZGLock)
                nIni:=Seconds()
                dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" pegou via IPCWaitEx o arquivo "+cFileName)
                cErro:=""
                SZG->ZG_DATA:=date()
                SZG->ZG_HORA:=time()
                cXML:=SZG->ZG_XML
                DEFAULT s239187191:=S_239_187_191
                if (SubStr(CXML,1,3)==s239187191)
                    cXML:=SubStr(cXML,4)
                    SZG->ZG_XML:=cXML
                endif
                limportXML:=importXML(@cXML,@cErro)
                lSZGLock:=SZG->(IsLocked())
                if .not.(lSZGLock)
                    lSZGLock:=recLock("SZG",.F.)
                endif
                if (lSZGLock)
                    cErro:=if(Empty(cErro)," ",cErro)
                    cErro:=if(.not.(ValType(cErro)=="C"),Varinfo("cErro",cErro,4,.F.,.T.),cErro)
                    cErro:=if((ValType(cErro)=="C"),cErro,"INVALID DATA TYPE ERROR IN "+procName(2)+"("+NToS(procLine(2))+")")
                    SZG->ZG_ERRO:=cErro
                    if (limportXML)
                        SZG->ZG_STATUS:="3"
                        SZG->ZG_ORCAME:=SL1->L1_NUM
                        SZG->ZG_DOC:=SL1->L1_DOC
                        SZG->ZG_SERIE:=SL1->L1_SERIE
                        SZG->ZG_KEYNFCE:=SL1->L1_KEYNFCE
                        if (lZGEMISSAO)
                            SZG->ZG_EMISSAO:=SL1->L1_EMISSAO
                        endif
                        nFim:=Seconds()
                        nFim:=if(nFim<nIni,nFim+(60*60*24),nFim)
                        dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" processou em "+NToS(nFim-nIni,7,3)+" segundos o XML do arquivo "+cFileName)
                    else
                        if empty(SZG->ZG_DOC)
                            SZG->ZG_STATUS:="2"
                            moveToErro(alltrim(SZG->ZG_ARQUIVO))
                            dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" encontrou um erro ao tentar processar o XML do arquivo "+cFileName+": "+cErro)
                        else
                            if .not.(SZG->ZG_STATUS=="3")
                                SZG->ZG_STATUS:="0"
                            else
                            	moveToDesc(alltrim(SZG->ZG_ARQUIVO))
                            endif
                        endif
                    endif
                    SZG->(msUnlock())
                else
                    dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" achou mas não conseguiu bloquear o registro do arquivo "+cFileName)
                endif
            else
                dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" achou mas não conseguiu bloquear o registro do arquivo "+cFileName)
            endif
        else
            dbgOut("Thread "+strZero(nThread,4)+" da filial "+cFilAnt+" recebeu via IPCWaitEx mas não conseguiu achar o arquivo "+cFileName)
        endif

        SZG->(MsUnLock())
        UnlockByName(cSZGLock,.T.,.T.)

    end while

    unlockByName(__lckJob,.T.,.T.)
    unlockByName(__killFileName,.T.,.T.)
    fErase(__killFileName)

    if (lRPCSet)
        if ((lEmpAnt).or.(lFilAnt))
            rpcSetType(RPC_TYPE)
            rpcSetEnv(c_EmpAnt,c_FilAnt)
        endif
        if (lRPCClean)
            rpcClearEnv()
        endif
    endif

    errorBlock(bErrorBlock)

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:importXML
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Interpreta o XML e faz a gravacao da venda no sigaloja
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function importXML(cXML,cErro)

    local aIde
    local aDet
    local aPgto

    local cXML
    local cItem
    local cAviso
    local cCPFCli
    local cNumOrc
    local cKeyNFCe

    local bError
    local bErrorBlock

    local lRet

    local i

    local cXMLID
    local cXMLIde
    local cXMLDet
    local cXMLPgto

    local cXMLType

    local cL4FORMA

    local cSB1Filial
    local cSL1Filial
    local cSL2Filial
    local cSL4Filial
    local cMH2Filial
    local cZZ1Filial

    local lL1XBASICM
    local lL1XVALICM

    local lL2XCF
    local lL2XBASICM
    local lL2XVALICM
    local lL2XALQICM

    local lZZ1FldOK
    local lExplodeXML

    local nXMLType
    
    local xCPFCli

    Private oXML

    aIde:=Array(0)
    aDet:=Array(0)
    aPgto:=Array(0)

    lRet:=.T.

    DEFAULT lExplodeXML:=.F.
    #ifdef __T4F_ACTIVE_DBG__
        lExplodeXML:=getNewPar("ES_SLOGXML",.T.)
    #else
         lExplodeXML:=getNewPar("ES_SLOGXML",.F.)
    #endif

    lL1XBASICM:=SL1->(FieldPos("L1_XBASICM")>0)
    lL1XVALICM:=SL1->(FieldPos("L1_XVALICM")>0)

    lL2XCF:=SL2->(FieldPos("L2_XCF")>0)
    lL2XBASICM:=SL2->(FieldPos("L2_XBASICM")>0)
    lL2XVALICM:=SL2->(FieldPos("L2_XVALICM")>0)
    lL2XALQICM:=SL2->(FieldPos("L2_XALQICM")>0)

    bError:={|e|(cErro:=e:Description,lRet:=.F.,jobError(e))}
    bErrorBlock:=errorBlock(bError)

    cErro:=""
    cAviso:=""
    if (lExplodeXML)
        dbgOut("cXML: "+cXML)
    endif
    oXML:=xmlParser(cXML,"_",@cErro,@cAviso)

    if empty(cErro)

        //0=Not Implemented (Invalid);1=SP:infCFe;2=RJ:nfeProc
        nXMLType:=if(("nfeProc"$cXML),2,if(("infCFe"$cXML),1,0))

        begin sequence
            //Invalido
            if (nXMLType==0)
                lRet:=.F.
                cErro:="XML Type Not Implemented or Invalid ValType: "
                cErro+=cXMLType
                if (lExplodeXML)
                    cErro+=CRLF
                    cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                endif
                break
            endif
            //SP:CFe
            if (nXMLType==1)
                cXMLType:="oXML:_CFe"
                if !(type(cXMLType)=="O")
                    lRet:=.F.
                    cErro:="XML Type Not Implemented or Invalid ValType: "
                    cErro+=cXMLType
                    if (lExplodeXML)
                        cErro+=CRLF
                        cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                    endif
                    break
                else
                    cXMLType+=":_infCFe"
                    cXMLID:=cXMLType
                    cXMLID+=":_Id:text
                    if !(type(cXMLID)=="C")
                        lRet:=.F.
                        cErro:="XML ID Not Found or Invalid ValType: "
                        cErro+=cXMLID
                        if (lExplodeXML)
                            cErro+=CRLF
                            cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                        endif
                    endif
                    break
                endif
            endif
            //RJ:nfeProc
            if (nXMLType==2)
                cXMLType:="oXML:_nfeProc"
                if !(type(cXMLType)=="O")
                    lRet:=.F.
                    cErro:="XML Type Not Implemented or Invalid ValType: "
                    cErro+=cXMLType
                    if (lExplodeXML)
                        cErro+=CRLF
                        cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                    endif
                    break
                else
                    cXMLType+=":_NFe"
                    if !(type(cXMLType)=="O")
                        lRet:=.F.
                        cErro:="XML Type Not Implemented or Invalid ValType: "
                        cErro+=cXMLType
                        if (lExplodeXML)
                            cErro+=CRLF
                            cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                        endif
                        break
                    else
                        cXMLType+=":_infNFe"
                        cXMLID:=cXMLType
                        cXMLID+=":_Id:text
                        if !(type(cXMLID)=="C")
                            lRet:=.F.
                            cErro:="XML ID Not Found or Invalid ValType: "
                            cErro+=cXMLID
                            if (lExplodeXML)
                                cErro+=CRLF
                                cErro+=Varinfo("oXML",oXML,4,.F.,.T.)
                            endif
                          endif
                        break
                    endif
                endif
            endif
        end sequence

        if (lRet)

            begin sequence

                cKeyNFCe:=&cXMLID

                ConOut(cKeyNFCe)

                lRet:=(ValType(cKeyNFCe)=="C")

                if !(lRet)
                    cErro:="XML cXMLID Inválido: "+cValToChar(cXMLID)
                    break
                endif

                cKeyNFCe:=SubStr(cKeyNFCe,4)
                lRet:=vldKey(cKeyNFCe,@cErro)
                if .not.(lRet)
                    cErro:="Chave da Nota Fiscal Já Importada: "+cKeyNFCe
                    break
                endif

                begin sequence
                    //Obtem o CPF do Destinatário
                    xCPFCli:=cXMLType
                    xCPFCli+=":_dest:_CPF"
                    if (Type(xCPFCli)=="O")
                        break
                    endif
                    //Obtem oCNPJ do Destinatário
                    xCPFCli:=cXMLType
                    xCPFCli+=":_dest:_CNPJ"
                    if (Type(xCPFCli)=="O")
                        break
                    endif
                    //Obtem o idEstrangeiro do Destinatário
                    xCPFCli:=cXMLType
                    xCPFCli+=":_dest:_idEstrangeiro"
                    if (Type(xCPFCli)=="O")
                        break
                    endif
                    xCPFCli:="''"
                end sequence

                //Obtem a Identificação do Destinatário
                xCPFCli:=&xCPFCli
                if (valtype(xCPFCli)=="C")
                	cCPFCli:=xCPFCli
				elseif (valtype(xCPFCli)=="O")
					varInfo("xCPFCli",xCPFCli)
					begin sequence
						cCPFCli:=xCPFCli:TEXT 
						varInfo("cCPFCli",cCPFCli)
					recover
						cCPFCli:=""
					end squence
				endif

                // valida se é nota em ambiente de producao (se for homologação,ignora)
                cXMLIde:=cXMLType
                cXMLIde+=":_ide"
                lRet:=vldIde(&cXMLIde,@aIde,@cErro)
                if .not.(lRet)
                    break
                endif

                // valida os itens
                cXMLDet:=cXMLType
                cXMLDet+=":_Det"
                lRet:=vldDet(&cXMLDet,aIde[4],@aDet,@cErro)
                if .not.(lRet)
                    break
                endif

                // valida os pagamentos
                cXMLPgto:=cXMLType
                if (nXMLType==1)
                    //SP:CFe
                    cXMLPgto+=":_Pgto"
                elseif (nXMLType==2)
                    //RJ:nfeProc
                    cXMLPgto+=":_pag"
                endif
                lRet:=vldPgto(&cXMLPgto,@aPgto,@cErro)
                if .not.(lRet)
                    break
                endif

            end sequence

        endif

        if (lRet)

            cSB1Filial:=xFilial("SB1")
            cSL1Filial:=xFilial("SL1")
            cSL2Filial:=xFilial("SL2")
            cSL4Filial:=xFilial("SL4")
            cMH2Filial:=xFilial("MH2")
            cZZ1Filial:=xFilial("ZZ1")

            lZZ1FldOK:=(.NOT.(Empty(RetSQLName("ZZ1"))))
            lZZ1FldOK:=(lZZ1FldOK).and.ChkFile("ZZ1")
            lZZ1FldOK:=(lZZ1FldOK).and.(ZZ1->(FieldPos("ZZ1_ORC")>0))
            lZZ1FldOK:=(lZZ1FldOK).and.(ZZ1->(FieldPos("ZZ1_DATA")>0))
            lZZ1FldOK:=(lZZ1FldOK).and.(ZZ1->(FieldPos("ZZ1_OBS")>0))

            cNumOrc:=GetSXENum("SL1","L1_NUM")
            ConfirmSX8()

            ConOut("[aImpCFe-importXML]-Gravação SL1: "+cNumOrc)

            begin transaction

                if SL1->(recLock("SL1",.T.))
                    SL1->L1_FILIAL:=cSL1Filial
                    SL1->L1_KEYNFCE:=cKeyNFCe
                    // também podemos usar o aIde[1],se quiserem manter um vinculo
                    SL1->L1_NUM:=cNumOrc
                    SL1->L1_SERSAT:=aIde[2]
                    SL1->L1_DOC:=padL(aIde[3],nTamDoc,"0")
                    SL1->L1_NUMCFIS:=padL(aIde[3],nTamDoc,"0")
                    SL1->L1_EMISSAO:=aIde[4]
                    SL1->L1_EMISNF:=aIde[4]
                    SL1->L1_DTLIM:=aIde[4]+730
                    SL1->L1_HORA:=aIde[5]
                    SL1->L1_OPERADO:=aIde[6]
                    SL1->L1_PDV:=aIde[7]
                    SL1->L1_ESTACAO:=aIde[8]
                    SL1->L1_SERIE:=aIde[9]
                    SL1->L1_CLIENTE:=cCliPad
                    SL1->L1_LOJA:=cLojaPad
                    SL1->L1_CGCCLI:=cCPFCli
                    SL1->L1_TIPOCLI:="F"
                    SL1->L1_VEND:=cVendPad
                    SL1->L1_CONDPG:="CN"
                    SL1->L1_IMPRIME:="5S"
                    SL1->L1_JUROS:=0
                    SL1->L1_TIPO:="V"
                    //SL1->L1_ARQIMP:=rtrim(SZG->ZG_ARQUIVO)
                    SL1->L1_CONFVEN:="SSSSSSSSNSSS"
                    SL1->L1_TPORC:="E"
                    SL1->L1_SITUA:="RX"

                    SB1->(dbSetOrder(1))
                    cItem:=strZero(1,nTamItem)

                    for i:=1 to len(aDet)

                        SB1->(MSSeek(cSB1Filial+aDet[i][1]))

                        if SL2->(recLock("SL2",.T.))
                            SL2->L2_FILIAL:=cSL2Filial
                            SL2->L2_NUM:=SL1->L1_NUM
                            SL2->L2_PRODUTO:=aDet[i][1]
                            SL2->L2_DESCRI:=aDet[i][2]
                            SL2->L2_ITEM:=cItem
                            SL2->L2_TABELA:="1"
                            SL2->L2_QUANT:=aDet[i][3]
                            SL2->L2_VLRITEM:=aDet[i][10]
                            SL2->L2_VRUNIT:=if(aDet[i][11]=="T",noRound(aDet[i][10]/aDet[i][3],2),round(aDet[i][10]/aDet[i][3],2))
                            SL2->L2_DOC:=SL1->L1_DOC
                            SL2->L2_SERIE:=SL1->L1_SERIE
                            SL2->L2_PDV:=SL1->L1_PDV
                            SL2->L2_CF:=aDet[i][12]
                            if Empty(aDet[i][13])
                                if (lZZ1FldOK)
                                    ConOut("[aImpCFe-importXML]-Gravação SL1: " +SL1->L1_NUM+ " Produto: " +SL2->L2_PRODUTO    + "- T E S   N A O   E N C O N T R A D A !")
                                    //Thiago Rocco 24-08-2016,aproveitamento da validação de TES para Gravar na tabela de LOG de integração
                                    if ZZ1->(Reclock("ZZ1",.T.))
                                        ZZ1->ZZ1_FILIAL:=cZZ1Filial
                                        ZZ1->ZZ1_ORC:=SL1->L1_NUM
                                        ZZ1->ZZ1_DATA:=dDataBase
                                        ZZ1->ZZ1_OBS:="Gravação SL1: " +Alltrim(SL1->L1_NUM)+ " Produto: " +Alltrim(SL2->L2_PRODUTO)    + "-Tes não encontrada."
                                        ZZ1->(MsUnlock())
                                    endif
                                    //Fim da manutenção
                                endif
                            endif
                            SL2->L2_TES:=aDet[i][13]
                            SL2->L2_EMISSAO:=SL1->L1_EMISSAO
                            SL2->L2_UM:=SB1->B1_UM
                            SL2->L2_LOCAL:=SB1->B1_LOCPAD
                            SL2->L2_PRCTAB:=if(aDet[i][11]=="T",noRound(aDet[i][10]/aDet[i][3],2),round(aDet[i][10]/aDet[i][3],2))
                            SL2->L2_VEND:=cVendPad
                            SL2->L2_ITEMSD1:="000000"

                            // calculo de desconto e acrescimo desconsidera o que veio no XML e apenas ajusta centavos de diferença de calculo (esta assim no fonte antigo)
                            SL2->L2_DESCPRO:=aDet[i][8] //max(0,SL2->((if(aDet[i][11]=="T",noRound(L2_QUANT*L2_VRUNIT,2),round(L2_QUANT*L2_VRUNIT,2)))-L2_VLRITEM))
                            SL2->L2_DESPESA:=aDet[i][9] //max(0,SL2->(L2_VLRITEM-(if(aDet[i][11]=="T",noRound(L2_QUANT*L2_VRUNIT,2),round(L2_QUANT*L2_VRUNIT,2)))))

                            SL2->L2_ORIGEM:=aDet[i][14]
                            SL2->L2_CODISS:=SB1->B1_CODISS
                            SL2->L2_POSIPI:=SB1->B1_POSIPI
                            SL2->L2_BASEICM:=SL2->L2_VLRITEM
                            SL2->L2_ORIGEM:=aDet[i][14]
                            SL2->L2_VALICM:=aDet[i][16]
                            SL2->L2_SITTRIB:=aDet[i][18]
                            SL2->L2_BASEPS2:=aDet[i][20]
                            SL2->L2_ALIQPS2:=aDet[i][21]
                            SL2->L2_VALPS2:=aDet[i][22]
                            SL2->L2_BASECF2:=aDet[i][24]
                            SL2->L2_ALIQCF2:=aDet[i][25]
                            SL2->L2_VALCF2:=aDet[i][26]
                            SL2->L2_VALISS:=aDet[i][30]

                            If (lL2XBASICM.and.lL2XVALICM.and.lL2XALQICM)
                                SL2->L2_XBASICM:=SL2->L2_VLRITEM
                                SL2->L2_XVALICM:=aDet[i][16]
                                SL2->L2_XALQICM:=aDet[i][15]
                            EndIf

                            If (lL2XCF)
                                SL2->L2_XCF:=aDet[i][12]
                            EndIf

                            // CAMPOS UTILIZADOS NO PONTO DE ENTRADA SANBRSD2
                            //SL2->L2__ICMRET:=SB1->B1_PICMRET
                            // SL2->L2__ICMENT:=if(SB1->B1_PICMRET<=0.and.SB1->B1_PICMENT<=0,0.01,SB1->B1_PICMENT)
                            //SL2->L2__ALIQRD:=SB0->B0_ALIQRED

                            SL2->(msUnlock())

                        endif

                        SL1->L1_VLRTOT+=SL2->(L2_VLRITEM+L2_DESCPRO-L2_DESPESA)
                        SL1->L1_VALBRUT+=SL2->(L2_VLRITEM+L2_DESCPRO-L2_DESPESA)
                        SL1->L1_VALMERC+=SL2->(L2_VLRITEM+L2_DESCPRO-L2_DESPESA)
                        SL1->L1_VLRLIQ+=SL2->L2_VLRITEM
                        SL1->L1_DESCONT+=SL2->L2_DESCPRO
                        SL1->L1_DESPESA+=SL2->L2_DESPESA
                        SL1->L1_VALICM+=SL2->L2_VALICM
                        SL1->L1_VALIPI+=SL2->L2_VALIPI
                        SL1->L1_VALISS+=SL2->L2_VALISS
                        SL1->L1_VALPIS+=SL2->L2_VALPIS
                        SL1->L1_VALCOFI+=SL2->L2_VALCOFI
                        SL1->L1_VALCSLL+=SL2->L2_VALCSLL
                        SL1->L1_BRICMS+=SL2->L2_BRICMS
                        SL1->L1_ICMSRET+=SL2->L2_ICMSRET

                        If (lL1XBASICM.and.lL1XVALICM.and.lL2XBASICM.and.lL2XALQICM)
                            SL1->L1_XBASICM+=SL2->L2_XBASICM
                            SL1->L1_XVALICM+=SL2->L2_XVALICM
                        EndIf

                        cItem:=__Soma1(cItem)

                    next i

                    for i:=1 to len(aPgto[1])

                        if SL4->(recLock("SL4",.T.))
                            SL4->L4_FILIAL:=cSL4Filial
                            SL4->L4_NUM:=SL1->L1_NUM
                            SL4->L4_DATA:=SL1->L1_EMISSAO
                            // Valor
                            SL4->L4_VALOR:=aPgto[1][i][2]-if(alltrim(aPgto[1][i][1])$"R$|CH",aPgto[2],0)
                            //Forma
                            SL4->L4_FORMA:=aPgto[1][i][1]
                            //Administradora
                            SL4->L4_ADMINIS:=aPgto[1][i][3]
                            //SL4->L4__DOC:=SL1->L1_DOC
                            //SL4->L4__SERIE:=SL1->L1_SERIE
                            //SL4->L4__EMISNF:=SL1->L1_EMISSAO
                            //SL4->L4__PDV:=SL1->L1_PDV
                            //SL4->L4__OPERAD:=SL1->L1_OPERADO
                            SL4->(msUnlock())
                        endif

                        cL4FORMA:=alltrim(SL4->L4_FORMA)

                        SL1->L1_DINHEIR+=if(cL4FORMA=="R$",SL4->L4_VALOR,0)
                        SL1->L1_CHEQUES+=if(cL4FORMA=="CH",SL4->L4_VALOR,0)
                        SL1->L1_CARTAO+=if(cL4FORMA=="CC",SL4->L4_VALOR,0)
                        SL1->L1_VLRDEBI+=if(cL4FORMA=="CD",SL4->L4_VALOR,0)
                        SL1->L1_CONVENI+=if(cL4FORMA=="CO",SL4->L4_VALOR,0)
                        SL1->L1_VALES+=if(cL4FORMA=="VA",SL4->L4_VALOR,0)
                        SL1->L1_FINANC+=if(cL4FORMA=="FI",SL4->L4_VALOR,0)
                        SL1->L1_OUTROS+=if(cL4FORMA=="CA",SL4->L4_VALOR,0)
                        SL1->L1_CREDITO+=if(cL4FORMA=="CR",SL4->L4_VALOR,0)

                    next i

                    //SL1->L1_OFERTA:=SL1->L1_CREDITO
                    //SL1->L1_TROCO1:=aPgto[2]
                    //SL1->L1_VALCTAB:=SL1->(L1_VALBRUT-L1_OUTROS)

                    SL1->(msUnlock())

                endif

                if MH2->(recLock("MH2",.T.))
                    MH2->MH2_FILIAL:=cMH2Filial
                    MH2->MH2_NUM:=SL1->L1_NUM
                    MH2->MH2_SERIE:=SL1->L1_SERIE
                    MH2->MH2_DOC:=SL1->L1_DOC
                    MH2->MH2_DOCCHV:=SL1->L1_KEYNFCE
                    MH2->MH2_XMLENV:=cXML
                    MH2->MH2_XMLRET:=cXML
                    MH2->MH2_TIPO:="VENDA"
                    MH2->MH2_STATUS:="SUCESSO"
                    MH2->MH2_TIME:=DToS(SL1->L1_EMISNF)+strTran(SL1->L1_HORA,":","")
                    MH2->MH2_MSGERR:=""
                    MH2->MH2_SITUA:="00"
                    MH2->(msUnlock())
                endif

            end transaction

            cErro:=" "

        endIf

    else

        if empty(cAviso)
            cErro+="- Ocorreu um erro desconhecido ao decodificar o XML."
            cErro+=CRLF
        else
            cErro+=cAviso
        endIf

        lRet:=.F.

    endif

    errorBlock(bErrorBlock)

return(lRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:vldIde
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Valida as informações da secao IDE do xml.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function vldIde(opNode,aIde,cErro)

    local cSerieSAT
    local cNumeroCX

    local cSLGFilial

    local lRet:=.T.

    aIde:=Array(9)

    Private oNode
    oNode:=opNode

    if oNode:_tpAmb:text=="2"
        cErro+="- CFe emitido em ambiente de homologacao. Nao sera importado."
        cErro+=CRLF
        lRet:=.F.
    else
        if (Type("oNode:_nSerieSAT:text")=="C")
            cSerieSAT:=oNode:_nSerieSAT:text
        else
            cSerieSAT:=GetNewPar("ES_XSERSAT","SRJ")
        endif
        // Criar: (4):LG_FILIAL+LG_SERSAT
        SLG->(dbSetOrder(RetOrder("SLG","LG_FILIAL+LG_SERSAT")))
        cSLGFilial:=xFilial("SLG")
        if SLG->(!dbSeek(cSLGFilial+cSerieSAT))
            // (2):LG_FILIAL+LG_ECFDIA
            SLG->(dbSetOrder(RetOrder("SLG","LG_FILIAL+LG_ECFDIA")))
            if (Type("oNode:_numeroCaixa:text")=="C")
                cSerieSAT:=oNode:_numeroCaixa:text
            else
                cNumeroCX:=GetNewPar("ES_XNROCX","001")
            endif
            if SLG->(dbSeek(cSLGFilial+cNumeroCX))
                if recLock("SLG",.F.)
                    SLG->LG_SERSAT:=cSerieSAT
                    SLG->(msUnlock())
                endif
            else
                lRet:=.F.
                cErro+="- Estacao com numero de caixa "+cNumeroCX+" ou numero de serie de PDV "+cSerieSAT+" nao encontrada."
                cErro+=CRLF
            endif
        endif

        if lRet

            // Numero interno (aleatório e não fiscal)
            if (Type("oNode:_cNF:text")=="C")
                aIde[1]:=oNode:_cNF:text
            else
                aIde[1]:=""
            endif

            // Numero de Série do Equip. SAT
            aIde[2]:=cSerieSAT

            // Numero do Cupom Fiscal (gerado pelo SAT)
            if (Type("oNode:_nCFe:text")=="C")
                aIde[3]:=oNode:_nCFe:text
            elseif (Type("oNode:_cNF:text")=="C")
                aIde[3]:=oNode:_cNF:text
            else
                aIde[3]:=""
            endif

            // Data da emissao
            if (Type("oNode:_dEmi:text")=="C")
                //<dEmi>20160825</dEmi>
                aIde[4]:=StoD(oNode:_dEmi:text)
            elseif (Type("oNode:_dhEmi:text")=="C")
                //<dhEmi>2016-11-03T11:00:48-02:00</dhEmi>
                aIde[4]:=oNode:_dhEmi:text
                if (("-"$aIde[4]).and.(":"$aIde[4]))
                    //<dhEmi>2016-11-03T11:00:48-02:00</dhEmi>
                    aIde[4]:=SubStr(aIde[4],1,10)
                endif
                aIde[4]:=StrTran(aIde[4],"-","")
                aIde[4]:=StoD(aIde[4])
            elseif (Type("oNode:_dhEvento:text")=="C")
                //<dhEvento>2016-12-10T11:03:12-02:00</dhEvento>
                aIde[4]:=oNode:_dhEvento:text
                if (("-"$aIde[4]).and.(":"$aIde[4]))
                    //<dhEvento>2016-12-10T11:03:12-02:00</dhEvento>
                    aIde[4]:=SubStr(aIde[4],1,10)
                endif
                aIde[4]:=StrTran(aIde[4],"-","")
                aIde[4]:=StoD(aIde[4])
            else
                aIde[4]:=CtoD("")
            endif

            // Hora da emissao
            if (Type("oNode:_hEmi:text")=="C")
                aIde[5]:=convTime(oNode:_hEmi:text)
            elseif (Type("oNode:_dhEmi:text")=="C")
                //<dhEmi>2016-11-03T11:00:48-02:00</dhEmi>
                aIde[5]:=oNode:_dhEmi:text
                if (("-"$aIde[5]).and.(":"$aIde[5]))
                    //<dhEmi>2016-11-03T11:00:48-02:00</dhEmi>
                    aIde[5]:=SubStr(aIde[5],12,8)
                endif
                aIde[5]:=convTime(aIde[5])
            elseif (Type("oNode:_dhEvento:text")=="C")
                //<dhEvento>2016-12-10T11:03:12-02:00</dhEvento>
                aIde[5]:=oNode:_dhEvento:text
                if (("-"$aIde[5]).and.(":"$aIde[5]))
                    //<dhEvento>2016-12-10T11:03:12-02:00</dhEvento>
                    aIde[5]:=SubStr(aIde[5],12,8)
                endif
                aIde[5]:=convTime(aIde[5])
            else
                aIde[5]:=convTime("000000")
            endif

            // Caixa
            aIde[6]:=cNumeroCX
            // PDV (id do Caixa conectado ao SAT)

            aIde[7]:=SLG->LG_PDV
            // Codigo da Estação

            aIde[8]:=SLG->LG_CODIGO

            // Serie utilizada no sistema por esta estação
            aIde[9]:=SLG->LG_SERIE

        endif

    endif

return lRet

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:vldDet
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Valida e carrega as formas de pagamento da venda
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function vldDet(opNode,dEmissao,aItens,cErro)

    local aDet
    local aItem

    local cQry
    local cTES

    local cUM
    local cCod
    local cDesc
    local cPosIPI
    local cCodBar
    local cCodISS

    local cSF4Filial
    local cSF4SQLName

    local lRet

    local i
    local nTES

    local lIcmsOk

    local nPreco

    Private oNode
    oNode:=opNode

    aDet:=if(valType(oNode)=="A",oNode,{oNode})

    lRet:=.T.
    cQry:=getNextAlias()

    aItem:=array(30)

    cSF4Filial:=xFilial("SF4")
    cSF4SQLName:=retSqlName("SF4")

    for i:=1 to len(aDet)

        Private oProd
        oProd:=aDet[i]:_prod

        Private oImposto
        oImposto:=aDet[i]:_imposto

        cCod:=oProd:_cProd:text
        cDesc:=oProd:_xProd:text
        cUM:=oProd:_uCom:text
        cPosIPI:=if(type("oProd:_NCM")<>"U",oProd:_NCM:text,"")
        cCodBar:=if(type("oProd:_cEAN")<>"U",oProd:_cEAN:text,"")
        cCodISS:=if(type("oProd:_imposto:_ISSQN:_cServTribMun")<>"U",oProd:_imposto:_ISSQN:_cServTribMun:text,"")
        nPreco:=val(oProd:_vUnCom:text)

        cCod:=chkProd(cCod,cDesc,cUM,cPosIPI,cCodBar,cCodISS,nPreco)

        // Produto
        aItem[1]:=cCod

        // descricao
        aItem[2]:=cDesc

        // quantidade
        aItem[3]:=val(oProd:_qCom:text)

        // valor unitario
        aItem[4]:=nPreco

        // valor total
        aItem[5]:=val(oProd:_vProd:text)

        // valor desconto
        aItem[6]:=if(type("oProd:_vDesc")<>"U",val(oProd:_vDesc:text),0)

        // outras despesas
        aItem[7]:=if(type("oProd:_vOutro")<>"U",val(oProd:_vOutro:text),0)

        // desconto sobre o total rateado nos itens
        aItem[8]:=if(type("oProd:_vRatDesc")<>"U",val(oProd:_vRatDesc:text),0)

        // acrescimo sobre o total rateado nos itens
        aItem[9]:=if(type("oProd:_vRatAcr")<>"U",val(oProd:_vRatAcr:text),0)

        // valor liquido (vProd-vDesc+vOutros-vRatDesc+vRatAcr)
        if type("oProd:_vItem")<>"U"
            aItem[10]:=val(oProd:_vItem:text)
        elseif type("oProd:_vProd")<>"U"
            aItem[10]:=val(oProd:_vProd:text)
        else
            aItem[10]:=0
        endif

        // indicador de regra de cálculo (T-trunca,A-arredonda)
        if type("oProd:_indRegra")<>"U"
            aItem[11]:=oProd:_indRegra:text
        elseif type("oProd:_indTot")<>"U"
            aItem[11]:=oProd:_indTot:text
        else
            aItem[11]:=""
        endif

        // cfop
        aItem[12]:=oProd:_CFOP:text

        /*
        if (nTES:=aScan(aTES,{|x| x[1]+x[2]==aItem[1]+aItem[12] }))>0
            cTES:=aTES[nTES,3]
        else
            // Permite aplicar uma regra especifica para seleção da TES
            cTES:=cTESPad
            if !empty(cTES)
                aAdd(aTES,{ aItem[1],aItem[12],cTES })
            else
                cTES:=cTESPad
            endIf
        endIf
        */
        aItem[13]:=""        // TES

        // ICMS
        // Origem do produto
        aItem[14]:=""
        // Aliquota ICMS
        aItem[15]:=0
        // Valor ICMS
        aItem[16]:=0
        // CST
        aItem[17]:=0
        // Conteúdo para L2_SITTRIB
        aItem[18]:=""

        if type("oImposto:_ICMS:_ICMS00")<>"U"
            // Origem do produto
            aItem[14]:=oImposto:_ICMS:_ICMS00:_orig:text
            // Aliquota ICMS
            aItem[15]:=val(oImposto:_ICMS:_ICMS00:_pICMS:text)
            // Valor do ICMS
            aItem[16]:=val(oImposto:_ICMS:_ICMS00:_vICMS:text)
            // Cód. Situação tributaria
            aItem[17]:=oImposto:_ICMS:_ICMS00:_CST:text
            // L2_SITTRIB
            aItem[18]:="T"+strZero(aItem[15]*100,4,0)
        elseif type("oImposto:_ICMS:_ICMS40")<>"U"
            // Origem do produto
            aItem[14]:=oImposto:_ICMS:_ICMS40:_orig:text
            // Cód. Situação tributaria
            aItem[17]:=oImposto:_ICMS:_ICMS40:_CST:text
            // L2_SITTRIB
            aItem[18]:=if(aItem[17]=="60","F",if(aItem[17]=="40","I","N"))
        elseif type("oImposto:_ICMS:_ICMSSN102")<>"U"
            // Origem do produto
            aItem[14]:=oImposto:_ICMS:_ICMSSN102:_orig:text
            // Cód. Situação tributaria
            aItem[17]:=oImposto:_ICMS:_ICMSSN102:CSOSN:text
        elseif type("oImposto:_ICMS:_ICMSSN900")<>"U"
            // Origem do produto
            aItem[14]:=oImposto:_ICMS:_ICMSSN900:_orig:text
            // Aliquota ICMS
            aItem[15]:=val(oImposto:_ICMS:_ICMSSN900:_pICMS:text)
            // Valor do ICMS
            aItem[16]:=val(oImposto:_ICMS:_ICMSSN900:_vICMS:text)
            // Cód. Situação tributaria
            aItem[17]:=oImposto:_ICMS:_ICMSSN900:CSOSN:text
        endIf

        // PIS
        // CST
        aItem[19]:=""
        // Base de Calculo
        aItem[20]:=0
        // Aliquota PIS
        aItem[21]:=0
        // Valor do imposto PIS
        aItem[22]:=0

        if type("oImposto:_PIS:_PISAliq")<>"U"
            aItem[19]:=oImposto:_PIS:_PISAliq:_CST:text
            aItem[20]:=val(oImposto:_PIS:_PISAliq:_vBC:text)
            aItem[21]:=val(oImposto:_PIS:_PISAliq:_pPIS:text)
            aItem[22]:=val(oImposto:_PIS:_PISAliq:_vPIS:text)
        elseif type("oImposto:_PIS:_PISNT")<>"U"
            aItem[19]:=oImposto:_PIS:_PISNT:_CST:text
        elseif type("oImposto:_PIS:_PISSN")<>"U"
            aItem[19]:=oImposto:_PIS:_PISSN:_CST:text
        endIf

        // Cofins
        // CST
        aItem[23]:=""
        // Base de Calculo
        aItem[24]:=0
        // Aliquota Cofins
        aItem[25]:=0
        // Valor do imposto Cofins
        aItem[26]:=0

        if type("oImposto:_COFINS:_COFINSAliq")<>"U"
            aItem[23]:=oImposto:_COFINS:_COFINSAliq:_CST:text
            aItem[24]:=val(oImposto:_COFINS:_COFINSAliq:_vBC:text)
            aItem[25]:=val(oImposto:_COFINS:_COFINSAliq:_pCOFINS:text)
            aItem[26]:=val(oImposto:_COFINS:_COFINSAliq:_vCOFINS:text)
        elseif type("oImposto:_COFINS:_COFINSNT")<>"U"
            aItem[23]:=oImposto:_COFINS:_COFINSNT:_CST:text
        elseif type("oImposto:_COFINS:_COFINSSN")<>"U"
            aItem[23]:=oImposto:_COFINS:_COFINSSN:_CST:text
        endIf

        //BEGIN 2016_07_25_Geraldo Sabino-Ajuste tratamento TES

            /* tratamento para a busca do tes conforme os calculos do XML */
            cQuery:=" SELECT *"
            cQuery+="   FROM "+cSF4SQLName+" SF4"
            cQuery+="  WHERE SF4.F4_FILIAL='"+cSF4Filial+"'"
            cQuery+="    AND SUBSTRING(SF4.F4_CF,2,3)='"+substr(aItem[12],2,3)+"' "
            cQuery+="    AND SF4.F4_CODIGO>'500' "
            cQuery+="    AND SF4.D_E_L_E_T_=' ' "

            cQuery:=ChangeQuery(cQuery)

            dbUseArea(.T.,"TOPCONN",TCGenQry(,,cQuery),cQry,.F.,.T.)

            // Origem do produto
            //aItem[14]:=""

            // Aliquota ICMS
            //aItem[15]:=0

            // Valor ICMS
            //aItem[16]:=0

            // CST
            //aItem[17]:=0

            // Conteúdo para L2_SITTRIB
            //aItem[18]:=""

            lIcmsOk:=.F.

            while (cQry)->(!eof())


                // guilherme-1-Criar BASEICMS,VALORICMS,CFOP,ALIQUOTA no SL2200  (Atualizar no Cabecalho do SL1,os totais do ICM e Base)
                // Na Carga do XML,gravar os campos conforme o real valor que está no XML
                //             2-Ajustar os Pontos de Entrada MSD2460 e SF2460I para gravar os valores que estão na SL2200 para o SD2200). (Acho que não precisa salvar o valor calculado pois estará errado)
                //                 Apos atualizar o SD2200,somar os valores e gravar no CABEC do SF2.
                //             3-Rodar a Rotina de Reprocessamento do Livro Fiscal para que reflita os impostos que foram calculados no Colibti.
                //             4-Como teremos o valor do total Gravado no F2_VALICM,e F2_BASEICM corretos (vindo do Colibri),servirá para uma comparação com o F3/FT finalmente
                //                 gerado,e dá para exportar em DBF para o Danilo conferir F2 com F3 (totais),e diretamente saber se tem alguma NF não batendo.
                //                 Se Rodar o dia 18.06.2016 (1498 xmls e a Maioria fechar,então,é o suficiente para que sexta e a semana que vem fechassemos o projeto.
                //             5-  Preciso que faca uma receita de bolo (rapida),para que o Danilo,possa operar sozinho (servicos,carga,copia xml ou ajuste SZG).
                 //            6-Uma rotina para limpar os movimentos conforme parametros seria um facilitador para reimportação.

                // Pega TES que Calcula ICMS,e a CST seja Igual ao XML e não tenha redução de Base de ICMS  e nao Esteja Bloqueado
                IF aItem[16]>0
                    IF  (cQry)->F4_ICM=="S".and.(cQry)->F4_SITTRIB==aItem[17]   /*.AND. (cQry)->F4_DUPLIC="S"*/   .and.(cQry)->F4_MSBLQL<>"1"
                        nValBsIc:=(aItem[16]*100)/aItem[15] //faz o calculo inverso para chegar na base usada

                        IF nValBsIc !=aItem[5]
                         IF (cQry)->F4_BASEICM=(nValBsIc/aItem[5])*100   /*.AND. (cQry)->F4_DUPLIC="S"*/ .and.(cQry)->F4_MSBLQL<>"1"
                             lIcmsOk:=.T.
                             Exit
                         ENDIF
                        Else
                         lIcmsOk:=.T.
                         Exit
                        ENDIF
                    ENDIF
                Else
                    IF  (cQry)->F4_ICM=="N" /*.and.(cQry)->F4_DUPLIC="S" */.and. ( (cQry)->F4_LFICM=="O".or.(cQry)->F4_LFICM=="I").and.(cQry)->F4_MSBLQL<>"1"
                        lIcmsOk:=.T.
                        Exit
                    ENDIF
                Endif

                (cQry)->(dbSkip())

            end while

            IF lIcmsOk
               aItem[13]:=(cQry)->F4_CODIGO
            Else
               aItem[13]:=" "
            Endif

            (cQry)->(dbCloseArea())

        //END 2016_07_25_Geraldo Sabino-Ajuste tratamento TES


        // ISS
        // Codigo do Servico
        aItem[27]:=""
        // Base de Calculo
        aItem[28]:=0
        // Aliquota
        aItem[29]:=0
        // Valor do imposto
        aItem[30]:=0

        if type("oProd:_imposto:_ISSQN")<>"U"
            aItem[27]:=oProd:_imposto:_ISSQN:_cServTribMun:text
            aItem[28]:=val(oProd:_imposto:_ISSQN:_vBC:text)
            aItem[29]:=val(oProd:_imposto:_ISSQN:_vAliq:text)
            aItem[30]:=val(oProd:_imposto:_ISSQN:_vISSQN:text)
        endIf

        aAdd(aItens,aClone(aItem))

    next i

return lRet

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:chkProd
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Avalia a existencia do produto,e cadastra caso nao o encontre.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function chkProd(cCod,cDesc,cUM,cPosIPI,cCodBar,cCodISS,nPreco)

    local cRet
    local cSB1Filial

    cRet:=padR(cCod,nTamProd)
    cSB1Filial:=xFilial("SB1")

    SB1->(dbSetOrder(1))
    if SB1->(!dbSeek(cSB1Filial+cRet))
        if SB1->(recLock("SB1",.T.))
            SB1->B1_FILIAL:=cSB1Filial
            SB1->B1_COD:=cRet
            SB1->B1_DESC:=cDesc
            SB1->B1_TIPO:="PA"
            SB1->B1_UM:=upper(cUM)
            SB1->B1_POSIPI:=if(!empty(cPosIPI),cPosIPI,getNewPar("ES_NCMPRLJ","22029000"))
            SB1->B1_CODBAR:=cCodBar
            SB1->B1_CODISS:=cCodISS
            SB1->B1_LOCPAD:="01"
            SB1->B1_GRUPO:="0001"
            SB1->B1_SEGUM:="UN"
            SB1->B1_LE:=1
            SB1->B1_LM:=1
            SB1->B1_CODITE:=CRIAVAR("B1_CODITE")
            SB1->B1_SITPROD:=CRIAVAR("B1_SITPROD")
            SB1->B1_ATIVO:=CRIAVAR("B1_ATIVO")
            SB1->B1_CRDEST:=CRIAVAR("B1_CRDEST")
            SB1->B1_GARANT:=CRIAVAR("B1_GARANT")
            SB1->(msUnlock())
        endif
    endIf

    /*if SB0->(!dbSeek(xFilial("SB0")+cRet))
        recLock("SB0",.T.)
        SB0->B0_FILIAL:=xFilial("SB0")
        SB0->B0_COD:=cRet
        SB0->B0_PRV1:=nPreco
        SB0->(msUnlock())
    elseIf SB0->B0_PRV1<>nPreco
        recLock("SB0",.F.)
        SB0->B0_PRV1:=nPreco
        SB0->(msUnlock())
    endIf
    */
return cRet

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:vldPgto
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Valida e carrega as formas de pagamento da venda
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function vldPgto(opNode,aPgto,cErro)

    local cI
    local cAdm
    local cForma
    local cOperadora

    local lRet
    local lMP

    local i
    local nValor
    local nForma

    local cSAEFilial

    private aMeios
    private oNode

    oNode:=opNode

    lRet:=.T.

    if (type("oNode:_MP")<>"U")
        lMP:=.T.
        aMeios:=if(valType(oNode:_MP)=="A",oNode:_MP,{oNode:_MP})
    elseif (type("oNode")=="A")
        aMeios:=oNode
    elseif (type("oNode:_tPag")<>"U")
        aMeios:={oNode}
    else
        aMeios:=Array(0)
    endif

    DEFAULT lMP:=.F.

    cSAEFilial:=xFilial("SAE")

    aPgto:={Array(0),0}

    for i:=1 to len(aMeios)

        cI:=NToS(i)
        nForma:=0

        if (lMP)
            if (type("aMeios["+cI+"]:_cMP")<>"U")
                nForma:=aScan(aFormas,{|x|x[1]==aMeios[i]:_cMP:text})
            endif
        elseif (type("aMeios["+cI+"]:_tPag")<>"U")
               nForma:=aScan(aFormas,{|x|x[1]==aMeios[i]:_tPag:text})
        endif

        if (nForma==0)
            cErro+="- Forma de pagamento "
            if (lMP)
                if (type("aMeios["+cI+"]:_cMP")<>"U")
                    cErro+=aMeios[i]:_cMP:text
                else
                    cErro+=" [ INVALIDA ] "
                endif
            else
                if (type("aMeios["+cI+"]:_tPag")<>"U")
                    cErro+=aMeios[i]:_tPag:text
                else
                    cErro+=" [ INVALIDA ] "
                endif
            endif
            cErro+=" nao encontrada."
            cErro+=CRLF
            lRet:=.F.
            exit
        endif

        cForma:=aFormas[nForma][2]

        if (cForma$"CC;CD")

            cAdm:=""
            cOperadora:=""

            if (lMP)
                If (type("aMeios["+cI+"]:_MP:_cAdmC")<>"U")
                    cOperadora:=aMeios[i]:_MP:_cAdmC:text
                endIf
            elseif (type("aMeios["+cI+"]:_card:_tBand")<>"U")
                cOperadora:=aMeios[i]:_card:_tBand:text
            endif

            SAE->(dbSetOrder(4))
            if SAE->(dbSeek(cSAEFilial+cOperadora))
                if (SAE->AE_TIPO==cForma)
                    cAdm:=SAE->AE_COD+"-"+Capital(SAE->AE_DESC)
                endif
            endif

            // para CC e CD,caso não encontre a administradora,cadastra uma na hora
            if empty(cAdm)
                SAE->(dbSetOrder(1))
                if SAE->(!dbSeek(cSAEFilial+"9"+cForma))
                    if SAE->(recLock("SAE",.T.))
                        SAE->AE_FILIAL:=cSAEFilial
                        SAE->AE_COD:="9"+cForma
                        SAE->AE_DESC:="ADM. SAT NAO CADASTRADA"
                        SAE->AE_TIPO:=cForma
                        if (lMP)
                            SAE->AE_SAT:=If(type("aMeios["+cI+"]:_MP:_cAdmC")<>"U",aMeios[i]:_MP:_cAdmC:text,"")
                        elseif type("aMeios["+cI+"]:_card::_tBand")<>"U"
                            SAE->AE_SAT:=aMeios[i]:_card:_tBand:text
                        else
                            SAE->AE_SAT:=""
                        endif
                        SAE->(msUnlock())
                    endif
                endif
                cAdm:=SAE->AE_COD+"-"+Capital(SAE->AE_DESC)
            endif

        endif

        if (lMP)
            nValor:=val(aMeios[i]:_vMP:text)
        else
            nValor:=val(aMeios[i]:_vPag:text)
        endif

        aAdd(aPgto[1],{cForma,nValor,cAdm})

    next i

    if (type("oNode:_vTroco")<>"U")
        aPgto[2]:=val(oNode:_vTroco:text)
    else
        aPgto[2]:=0
    endif

    if empty(aPgto[1])
        cErro+="- Nenhum pagamento no arquivo."
        cErro+=CRLF
        lRet:=.F.
    endif

return(lRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:jobError
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Tratamento de erro na leitura do objeto XML
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function jobError(e)

    local lIsLocked

    if isInCallStack("IMPORTXML")
        lSZGLock:=SZG->(IsLocked())
        if ((lSZGLock).or.(recLock("SZG",.F.)))
            SZG->ZG_STATUS:="2"
            SZG->ZG_ERRO:="Erro fatal: "+e:Description+" on "+procName(2)+"("+NToS(procLine(2))+")"
            if .not.(lSZGLock)
                SZG->(msUnlock())
            endif
        endif
    endif

    dbgOut("Erro fatal: "+e:Description+" on "+procName(2)+"("+NToS(procLine(2))+")")

return(.T.)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:moveTo
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Move Arquivo de/para determinada pasta
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function moveTo(cFrom,cTo)
    if file(cTo)
        fErase(cTo)
    endif
    if (fRename(cFrom,cTo)<0)
        dbgOut("Erro ao tentar mover o arquivo "+cFrom+" para "+cTo+": "+fError())
    endif
return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:moveToLido
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Move Arquivo de/para determinada pasta
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function moveToLido(cFile)
    moveTo(__filePath+cFile,__lidosPath+cFile)
    if file(__errosPath+cFile)
        fErase(__errosPath+cFile)
    endif
return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:moveToErro
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Move Arquivo de/para determinada pasta
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function moveToErro(cFile)
    if file(__filePath+cFile)
        moveTo(__filePath+cFile,__errosPath+cFile)
    elseIf file(__lidosPath+cFile)
        moveTo(__lidosPath+cFile,__errosPath+cFile)
    endIf
return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:moveToDesc
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Move Arquivo de/para determinada pasta
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function moveToDesc(cFile)
    if file(__filePath+cFile)
        moveTo(__filePath+cFile,__descaPath+cFile)
    elseIf file(__lidosPath+cFile)
        moveTo(__lidosPath+cFile,__descaPath+cFile)
    endIf
return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:loadSlaves
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Carrega do SX5,da tabela Z2,os slaves disponiveis para distribuicao das threads de importacao
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function loadSlaves()

    local aRet

    local cIP

    local cSX5Filial
    local cSX5Descri
    local cSX5KeySeek

    local cGetServerIP

    local nAt
    local nPort

    aRet:=Array(0)

    cGetServerIP:=getServerIP()

    SX5->(dbSetOrder(1))
    cSX5Filial:=xFilial("SX5")
    cSX5KeySeek:=cSX5Filial
    cSX5KeySeek+="Z2"
    SX5->(dbSeek(cSX5KeySeek))
    while SX5->(!eof().and.(X5_FILIAL+X5_TABELA)==cSX5KeySeek)
        cSX5Descri:=AllTrim(SX5->X5_DESCRI)
        nAt:=At(":",cSX5Descri)
        if (nAt>0)
            cIP:=left(cSX5Descri,nAt-1)
            nPort:=val(subs(cSX5Descri,nAt+1))
        else
            cIP:=getNewPar("ES_RPCSRVJ",cGetServerIP)
            nPort:=val(cSX5Descri)
        endif
        aAdd(aRet,{cIP,nPort})
        SX5->(dbSkip())
    end while

return(aRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:timeToGo
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Funcao que calcula o tempo de vida da thread.
                   (Considera a virada da meia noite)
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function timeToGo(nStart,nLimit)

    local nNow
    local ltimeToGo

    nNow:=Seconds()

    // se agora for menor que o início,virou o dia.
    if (nNow<nStart)
        // adiciono um dia na contagem,pra comparar direito
        nNow+=((60*60)*24)
    endif

    ltimeToGo:=((nNow-nStart)>=nLimit)

return(ltimeToGo)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:isKilled
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Verifica se foi solicitada a morte da thread,seja pelo monitor Protheus ou pelo monitor de cupons
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function isKilled()
    local lisKilled
    lisKilled:=killApp()
    if .not.(lisKilled)
        lisKilled:=file(__killFileName+"die")
    endif
return lisKilled

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:newThreads
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Cria novas threads de jobs de processamento
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function newThreads(nThreads,nMaxThreads,nLifeTime,nTimeOut)

    local cEnvServer

    local nNew
    local nThread

    nNew:=0
    nThread:=1

    cEnvServer:=getEnvServer()
    ConOut("["+cEnvServer+"] Foram solicitadas "+NToS(nThreads)+" novas threads para a Empresa/Filial "+cEmpAnt+"/"+cFilAnt)

    while (!isKilled().and.(nNew<nThreads).and.(nThread<=nMaxThreads))
        // Semaforo para existir apenas uma instância deste job para cada empresa+filial
        if lockByName(__lckJob,.T.,.T.)
            // Libera o semaforo,pois quem vai manter bloqueado é a própria thread para provar que está viva
            unlockByName(__lckJob,.T.,.T.)
            startJob("u_aImpCFej",cEnvServer,.F.,cEmpAnt,cFilAnt,nThread,nLifeTime+(nThread*3),nTimeOut)
            nNew++
        endif
        nThread++
    end while

    if (nNew>0)
        nThread:=0
        // segura todo o processo por alguns segundos porque enquanto uma das novas threads não subir,pode dar interpretação incorreta de gargalo
        while (!isKilled().and.(nThread++<3))
            sleep(1000)
        end while
    endif

    ConOut("["+cEnvServer+"] Foram criadas "+NToS(nNew)+" threads para a Empresa/Filial "+cEmpAnt+"/"+cFilAnt)

return(nNew)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:dbug
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Gera um arquivo de log quando em modo debug
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function dbgOut(cMsg)

    local cdebugFile
    cdebugFile:=getdebugFile()
    if !empty(cdebugFile)
        acaLog(cdebugFile,dtoc(date())+" "+time()+" "+padR(procName(1)+"("+NToS(procLine(1))+")",20,".")+": "+cMsg)
    endif

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:getdebugFile
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Gera um arquivo de log quando em modo debug
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function getdebugFile()
    local cDate
    local cNome
    local cDrive
    local cExtensao
    local cDiretorio
    static s__debugFile
    DEFAULT s__debugFile:=__debugFile
    if ("_debug.log"$lower(s__debugFile))
        SplitPath (s__debugFile,@cDrive,@cDiretorio,@cNome,@cExtensao)
        if empty(cNome)
            cNome:="_debug_"
        endif
        cNome+=DToS(MsDate())
        cNome+="_"
        cNome+=StrTran(Time(),":","_")
        if empty(cExtensao)
            cExtensao:=".log"
        endif
        s__debugFile:=cDrive
        s__debugFile+=cDiretorio
        s__debugFile+=cNome
        s__debugFile+=cExtensao
    else
        cDate:=DToS(MsDate())
        if (.not.(cDate$lower(s__debugFile)))
            SplitPath (s__debugFile,@cDrive,@cDiretorio,@cNome,@cExtensao)
            if empty(cNome)
                cNome:="_debug_"
            endif
            cNome+=DToS(MsDate())
            cNome+="_"
            cNome+=StrTran(Time(),":","_")
            if empty(cExtensao)
                cExtensao:=".log"
            endif
            s__debugFile:=cDrive
            s__debugFile+=cDiretorio
            s__debugFile+=cNome
            s__debugFile+=cExtensao
        endif
    endif
return(s__debugFile)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:convTime
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Converte string do formato hhmmss para hh:mm:ssUsada para ler horario do XML
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function convTime(cTime)
    DEFAULT cTime:="00:00:00"
    if (":"$cTime)
        //00:00:00
        return(cTime)
    else
        //000000
        return(subs(cTime,1,2)+":"+subs(cTime,3,2)+":"+subs(cTime,5,2))
    endif

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:setKillF
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Cria o controle de sessao para poder ser finalizado pelo monitor de cupons
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function setKillF()

    local lRet

    lRet:=.F.

    if file(__killFileName)
        fErase(__killFileName)
    endIf

    acaLog(__killFileName,dtoc(date())+" "+time())
    if file(__killFileName)
        lRet:=lockByName(__killFileName,.T.,.T.)
        if !lRet
            dbgOut("Não foi possível criar o lockByName para kill da thread")
        endif
    else
        dbgOut("Não foi possível criar o arquivo de lock para kill da thread")
    endif

return(lRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:aImpCFeK
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Funcao para finalizar todas as threads e jobs de controle.Utilizada a partir do monitor de cupons.
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
user function aImpCFeK()

    local nResta

    processa({|lEnd|(nResta:=killAll(@lEnd))},"A G U A R D E")

    if (nResta>0)
        msgAlert("Operação interrompida antes da confirmação de término de "+NToS(nResta)+" threads.")
    else
        msgInfo("Todas as threads finalizadas com sucesso.")
    endIf

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:killAll
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Solicita o Fechamento das Threads
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function killAll(lEnd)

    local aKill
    local aWait

    local i
    local nQtd

    aKill:=directory("\semaforo\aImpCFe.??????")
    aWait:=Array(0)
    nQtd:=len(aKill)

    procRegua(len(aKill)+1)

    incProc("Enviando comando de finalização para as threads")

    while ((!lEnd).and.(!empty(aKill)))

        if (len(aKill)<>nQtd)
            nQtd:=len(aKill)
            incProc("Aguardando finalização. Restam "+NToS(nQtd)+" threads")
        endIf

        for i:=1 to len(aKill)
            if lockByName("\semaforo\"+aKill[i][1],.T.,.T.)
                unlockByName("\semaforo\"+aKill[i][1],.T.,.T.)
                fErase("\semaforo\"+aKill[i][1])
                fErase("\semaforo\"+aKill[i][1]+"die")
            else
                aAdd(aWait,aClone(aKill[i]))
                if !file("\semaforo\"+aKill[i][1]+"die")
                    acaLog("\semaforo\"+aKill[i][1]+"die",dtoc(date())+" "+time())
                endIf
            endIf
        next i

        aKill:=aClone(aWait)
        aSize(aWait,0)
        // meio segundo para o loop
        sleep(500)

    end while

return(len(aKill))

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:limpaBase
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Limpa a Base para Novas Cargas
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function limpaBase()

    if !baseTeste
        return .F.
    endif

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

    if SF2->(dbSeek(SZG->(ZG_FILIAL+ZG_DOC+ZG_SERIE)))
        if SF2->(recLock("SF2",.F.))
            SF2->(dbDelete())
            SF2->(msUnlock())
        endif
    endif

    CD2->(dbSeek(SZG->(ZG_FILIAL+"S"+ZG_SERIE+ZG_DOC)))
    while CD2->(!eof().and.CD2_FILIAL+CD2_TPMOV+CD2_SERIE+CD2_DOC==SZG->(ZG_FILIAL+"S"+ZG_SERIE+ZG_DOC))
        if CD2->(recLock("CD2",.F.))
            CD2->(dbDelete())
            CD2->(msUnlock())
        endif
        CD2->(dbSkip())
    end while

    SFT->(dbSeek(SZG->(ZG_FILIAL+"S"+ZG_SERIE+ZG_DOC)))
    while SFT->(!eof().and.FT_FILIAL+FT_TIPOMOV+FT_SERIE+FT_NFISCAL==SZG->(ZG_FILIAL+"S"+ZG_SERIE+ZG_DOC))
        if SFT->(recLock("SFT",.F.))
            SFT->(dbDelete())
            SFT->(msUnlock())
        endif
        SFT->(dbSkip())
    end while

    SF3->(dbSeek(SZG->(ZG_FILIAL+ZG_DOC+ZG_SERIE)))
    while SF3->(!eof().and.F3_FILIAL+F3_NFISCAL+F3_SERIE==SZG->(ZG_FILIAL+ZG_DOC+ZG_SERIE))
        if SF3->F3_CFO>"5"
            if SF3->(recLock("SF3",.F.))
                SF3->(dbDelete())
                SF3->(msUnlock())
            endif
        endif
        SF3->(dbSkip())
    end while

    SD2->(dbSeek(SZG->(ZG_FILIAL+ZG_DOC+ZG_SERIE)))
    while SD2->(!eof().and.D2_FILIAL+D2_DOC+D2_SERIE==SZG->(ZG_FILIAL+ZG_DOC+ZG_SERIE))
        if SD2->(recLock("SD2",.F.))
            SD2->(dbDelete())
            SD2->(msUnlock())
        endif
        SD2->(dbSkip())
    end while

    SE1->(dbSeek(SF2->(F2_FILIAL+F2_CLIENTE+F2_LOJA+F2_PREFIXO+F2_DUPL)))
    while SE1->(!eof().and.E1_FILIAL+E1_CLIENTE+E1_LOJA+E1_PREFIXO+E1_NUM==SF2->(F2_FILIAL+F2_CLIENTE+F2_LOJA+F2_PREFIXO+F2_DUPL))
        if SE1->(recLock("SE1",.F.))
            SE1->(dbDelete())
            SE1->(msUnlock())
        endif
        SE1->(dbSkip())
    end while

    SL4->(dbSeek(SZG->(ZG_FILIAL+ZG_ORCAME)))
    while SL4->(!eof().and.L4_FILIAL+L4_NUM==SZG->(ZG_FILIAL+ZG_ORCAME))
        if SL4->(recLock("SL4",.F.))
            SL4->(dbDelete())
            SL4->(msUnlock())
        endif
        SL4->(dbSkip())
    end while

    SL2->(dbSeek(SZG->(ZG_FILIAL+ZG_ORCAME)))
    while SL2->(!eof().and.L2_FILIAL+L2_NUM==SZG->(ZG_FILIAL+ZG_ORCAME))
        if SL2->(recLock("SL2",.F.))
            SL2->(dbDelete())
            SL2->(msUnlock())
        endif
        SL2->(dbSkip())
    end while

    SL1->(dbSeek(SZG->(ZG_FILIAL+ZG_ORCAME)))
    while SL1->(!eof().and.L1_FILIAL+L1_NUM==SZG->(ZG_FILIAL+ZG_ORCAME))
        if SL1->(recLock("SL1",.F.))
            SL1->(dbDelete())
            SL1->(msUnlock())
        endif
        SL1->(dbSkip())
    end while

    if MH2->(dbSeek(SZG->(ZG_FILIAL+ZG_ORCAME)))
        if MH2->(recLock("MH2",.F.))
            MH2->(dbDelete())
            MH2->(msUnlock())
        endif
        MH2->(dbSkip())
    end

    if SZG->(recLock("SZG",.F.))
        SZG->(dbDelete())
        SZG->(msUnlock())
    endif

return(.T.)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:vldKey
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Limpa a Base para Novas Cargas
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function vldKey(cKeyNFCe,cErro)

    local lRet
    local cNextAlias

    lRet:=.T.
    cNextAlias:=GetNextAlias()

    beginSQL alias cNextAlias
        SELECT ZG_ARQUIVO
          FROM %table:SZG% SZG
         WHERE SZG.%notDel%
           AND SZG.ZG_FILIAL=%xFilial:SZG%
           AND SZG.ZG_KEYNFCE=%exp:cKeyNFCe%
           AND SZG.ZG_STATUS IN ('3')
    endSQL

    if (cNextAlias)->(!eof())
        lRet:=.F.
        cErro+="- CFe já importado no arquivo "
        cErro+=(cNextAlias)->ZG_ARQUIVO
        cErro+="."
        cErro+=CRLF
    endIf

    (cNextAlias)->(dbCloseArea())
    dbSelectArea("SZG")

return(lRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:loadFilSAT
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Identifica as filiais que utilizam SAT em alguma estacao
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function loadFilSAT()

    local aRet
    local cAlias

    cAlias:=getNextAlias()

    beginSQL alias cAlias
        SELECT DISTINCT SLG.LG_FILIAL
          FROM %table:SLG% SLG
         WHERE SLG.%notDel%
           AND SLG.LG_USESAT='T'
           AND SLG.LG_SERSAT<>' '
         ORDER BY SLG.LG_FILIAL
    endSQL

    aRet:=Array(0)

    while (cAlias)->(!eof())
        aAdd(aRet,(cAlias)->LG_FILIAL)
        (cAlias)->(dbSkip())
    end while

    (cAlias)->(dbCloseArea())
    dbSelectArea("SLG")

return(aRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:aImpCFeZ
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Identifica as filiais que utilizam SAT em alguma estacao
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
user function aImpCFeZ(cEmp,cFil)

    local c_EmpAnt
    local c_FilAnt

    local lEmpAnt
    local lFilAnt
    local lEmpFil

    local lRPCSet
    local lRPCClean

    DEFAULT cEmp:="01"
    DEFAULT cFil:="01"

    lEmpAnt:=(Type("cEmpAnt")=="C")
    lFilAnt:=(Type("cFilAnt")=="C")
    lEmpFil:=((lEmpAnt).and.(lFilAnt))
    if (lEmpAnt).and.(lFilAnt)
        c_EmpAnt:=cEmpAnt
        c_FilAnt:=cFilAnt
        lRPCClean:=.F.
    else
        lRPCClean:=.T.
    endif

    lRPCSet:=(!(lEmpFil).or.!(cEmpAnt==cEmp).or.!(cFilAnt==cFil))

    if (lRPCSet)
        rpcSetType(RPC_TYPE)
        rpcSetEnv(cEmp,cFil)
    endif

    if msgYesNo("Deseja limpar tudo relacionado ao SAT ?")
        tcSQLExec("DELETE FROM "+RetSqlName("SL2")+" WHERE EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SL1")+" WHERE L1_FILIAL=L2_FILIAL AND L1_NUM=L2_NUM AND L1_KEYNFCE>' ' AND D_E_L_E_T_=' ')")
        tcSQLExec("DELETE FROM "+RetSqlName("SL4")+" WHERE EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SL1")+" WHERE L1_FILIAL=L4_FILIAL AND L1_NUM=L4_NUM AND L1_KEYNFCE>' ' AND D_E_L_E_T_=' ')")
        tcSQLExec("DELETE FROM "+RetSqlName("SL1")+" WHERE L1_KEYNFCE>' '")
        tcSQLExec("DELETE FROM "+RetSqlName("SE1")+" WHERE EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SF2")+" WHERE F2_FILIAL=E1_FILIAL AND F2_DOC=E1_NUM AND F2_SERIE=E1_PREFIXO AND F2_CHVNFE>' ' AND F2_ESPECIE IN ('NFCE','SATCE') AND D_E_L_E_T_=' ')")
        tcSQLExec("DELETE FROM "+RetSqlName("SE5")+" WHERE EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SF2")+" WHERE F2_FILIAL=E5_FILIAL AND F2_DOC=E5_NUMERO AND F2_SERIE=E5_PREFIXO AND F2_CHVNFE>' ' AND F2_ESPECIE IN ('NFCE','SATCE') AND D_E_L_E_T_=' ')")
        tcSQLExec("DELETE FROM "+RetSqlName("SD2")+" WHERE EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SF2")+" WHERE F2_FILIAL=D2_FILIAL AND F2_DOC=D2_DOC AND F2_SERIE=D2_SERIE AND F2_CHVNFE>' ' AND F2_ESPECIE IN ('NFCE','SATCE') AND D_E_L_E_T_=' ') ")
        tcSQLExec("DELETE FROM "+RetSqlName("CD2")+" WHERE CD2_TPMOV='S' AND EXISTS (SELECT R_E_C_N_O_ FROM "+RetSqlName("SF2")+" WHERE F2_FILIAL=CD2_FILIAL AND F2_DOC=CD2_DOC AND F2_SERIE=CD2_SERIE AND F2_CHVNFE>' ' AND F2_ESPECIE IN ('NFCE','SATCE') AND D_E_L_E_T_=' ')")
        tcSQLExec("DELETE FROM "+RetSqlName("SF2")+" WHERE F2_CHVNFE>' ' AND F2_ESPECIE IN ('NFCE','SATCE')")
        tcSQLExec("DELETE FROM "+RetSqlName("SF3")+" WHERE F3_CHVNFE>' ' AND F3_ESPECIE IN ('NFCE','SATCE')")
        tcSQLExec("DELETE FROM "+RetSqlName("SFT")+" WHERE FT_CHVNFE>' ' AND FT_ESPECIE IN ('NFCE','SATCE')")
        tcSQLExec("DELETE FROM "+RetSqlName("MH2")+" ")
        tcSQLExec("DELETE FROM "+RetSqlName("SZG")+" ")
    endif

    msgInfo("Pronto!")

    if (lRPCSet)
        if ((lEmpAnt).or.(lFilAnt))
            rpcSetType(RPC_TYPE)
            rpcSetEnv(c_EmpAnt,c_FilAnt)
        endif
        if (lRPCClean)
            rpcClearEnv()
        endif
    endif

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:readXML
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Le o arquivo XML em modo binario para nao ter limitacaode tamanho de arquivo
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
Static Function readXML(cFile)

    local bfRead

    local cRet
    local cBuff

    local nHdl
    local nSize
    local nRead

    cRet:=""
    nRead:=0

    nSize:=65535
    cBuff:=Space(nSize)

    if file(cFile)
        nHdl:=fOpen(cFile,FO_READ)
        if (nHdl>=0)
            bfRead:={|nRead,nHdl,cBuff,nSize|(nRead:=fRead(@nHdl,@cBuff,@nSize))>0}
            while Eval(bfRead,@nRead,@nHdl,@cBuff,@nSize)
                cRet+=left(cBuff,nRead)
                cBuff:=Space(nSize)
            end while
            fClose(nHdl)
        endif
    endif

return(cRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:countJobs
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Conta quantas threads estao ativas para a filial
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function countJobs(nMaxThreads)

    local nRet
    local nThread

    nRet:=0

    for nThread:=1 to nMaxThreads
        if !lockByName(__lckJob,.T.,.T.)
            nRet++
        else
            unlockByName(__lckJob,.T.,.T.)
        endIf
    next nThread

return nRet

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:getXMLFile
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Conta quantas threads estao ativas para a filial
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function getXMLFile(cDirectory,lconnectFTP)

    local aFTPDir
    local cCurrentD
    local cCurrentF
    local cFullName

    local i
    local x

    DEFAULT cDirectory:="AFTER"
    
    aFTPDir:=Array(0)

    DEFAULT lconnectFTP:=connectFTP("open")
    if lconnectFTP

        ConOut("[aImpCFe]-Conectou FTP ")
        //obtem os diretorios do FTP
        aFTPDir:= ftpDirectory("*.*","D",.T.)

        for i:=1 to len(aFTPDir)
         
            cCurrentD:=AllTrim(Upper(aFTPDir[i][1]))
            If (cCurrentD==cDirectory)
                
                //muda a pasta
                lretlog:=ftpDirChange("/"+cCurrentD)
                if !lretlog
                	lretlog:=ftpDirChange(cCurrentD)  
                endif
                   
                If !lretlog
                   ConOut("Não foi possivel nodificar diretorio "+cCurrentD)
                else
            		ConOut("[aImpCFe]-xml pasta "+cCurrentD)
            		//verifica se existem XMLs na pasta para copia
                    aFTPFile:=ftpDirectory("*.XML",nil,.F.)
                    if ((cCurrentD=="AFTER").and.empty(aFTPFile))
                    	getXMLFile("ENVIADAS",@lconnectFTP)
                    else
	                    for x:=1 to len (aFTPFile)
	                    	cCurrentF:=aFTPFile[x][1]
	                        cFullName:=(__filePath+cCurrentF)
	                        //faz a copia da pasta para o servidor do protheus
	                        ConOut("[aImpCFe]-Copia: "+cCurrentF+" Pasta: "+__filePath)
	                        ftpDownload(cFullName,cCurrentF)
	                        //verifica se copiou e apaga da origem
	                        if file(cFullName)
	                            ftpErase(cCurrentF)
	                        endif
	                    next x
                	endif
                EndIf

            endif

        next i

    endif

    if lconnectFTP
    	connectFTP("close")
    endif

return

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:connectFTP
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Conta quantas threads estao ativas para a filial
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//--------------------------------------------------------------------------------------------------------------
static function connectFTP(cOption)

    local cEnd
    local cUser
    local cPass

    local lRet

    local nPort

    cEnd:=alltrim(getNewPar("ES_AXMLEND","192.168.10.29"))
    //cEnd:=alltrim(getNewPar("ES_AXMLEND"))
    nPort:=getNewPar("ES_AXMLPOR",21)
    //nPort:=getNewPar("ES_AXMLPOR")
    cUser:=alltrim(getNewPar("ES_FTPUSER","time4fun\ftpxml"))
    cPass:=alltrim(getNewPar("ES_FTPPASS","mnbv@1212"))

    cOption:=alltrim(cOption)
    if (cOption=="open")
        lRet:=FTPConnect(cEnd,nPort,cUser,cPass)
    elseif (cOption=="close")
        lRet:=FtpDisconnect()
    else
        lRet:=.F.
    endif

return(lRet)

//--------------------------------------------------------------------------------------------------------------
    /*/
        Programa:aimpcfe.prw
        Funcao:tsXmlSat
        Autor:Alt Ideias & TOTALIT
        Data:06/10/2016
        Descricao: Conta quantas threads estao ativas para a filial
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
        |2016/12/03| Marinaldo de Jesus (www.totalit.com.br)       | Otimizacao/Importação NFCe/RJ             |
        +----------+-----------------------------------------------+-------------------------------------------+
    /*/
//-------------------------------------------------------------------------------------------------------------
user function tsXmlSat(pEmp,pFil)
    u_aImpCFef(pEmp,pFil,1)
return
