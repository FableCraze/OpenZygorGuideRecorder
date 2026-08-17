# Open Zygor Guide Recorder

Addon experimental para **World of Warcraft Retail 12.1.x / Midnight** que grava ações de questing e gera um esqueleto de guia compatível com a sintaxe observada no **Zygor Guides Viewer**.

> Este projeto não é afiliado, endossado ou distribuído pela Zygor Guides. Ele não inclui conteúdo proprietário de guias; apenas registra ações do próprio jogador e gera texto no formato de autoria observado nos arquivos fornecidos pelo usuário.

## Compatibilidade

- World of Warcraft Retail / Midnight 12.1.x
- `## Interface: 120100`
- Zygor Guides Viewer: exportação baseada na sintaxe de guias Retail fornecida como referência

## Instalação

1. Feche o World of Warcraft.
2. Copie a pasta `OpenZygorGuideRecorder` para:

   `World of Warcraft/_retail_/Interface/AddOns/`

3. O caminho final deve ficar assim:

   `World of Warcraft/_retail_/Interface/AddOns/OpenZygorGuideRecorder/OpenZygorGuideRecorder.toc`

4. Abra o WoW e habilite **Open Zygor Guide Recorder** na lista de addons.
5. Use `/ozgr`.

## Fluxo básico

1. Abra `/ozgr`.
2. Dê um nome para a sessão.
3. Clique em **Iniciar**.
4. Jogue normalmente.
5. Use **+ Interação** quando quiser marcar explicitamente o alvo atual.
6. Use **+ Waypoint** para marcar posições importantes.
7. Use **+ Tip** para registrar instruções manuais.
8. Clique em **Parar**.
9. Clique em **Exportar Zygor**.
10. Copie o texto e revise antes de colocá-lo em um arquivo de guia.

## O que é gravado automaticamente

- Aceite de quests (`QUEST_ACCEPTED`)
- Entrega de quests (`QUEST_TURNED_IN`)
- Mudanças de objetivos de quest
- NPC recente associado a quest/gossip quando disponível
- Opção de gossip selecionada quando a chamada pode ser observada
- Mapa e coordenadas do jogador
- Kills recentes usados para correlacionar objetivos de combate
- Loot recente usado para correlacionar objetivos de coleta
- Entrada e saída de veículos
- Mudanças de cenário
- Level up
- Mudança de mapa/zona

## O que é semiautomático/manual

Algumas informações não podem ser inferidas com segurança apenas pelas APIs do jogo. O addon oferece marcadores manuais para complementar a gravação:

- `+ Interação`
- `+ Waypoint`
- `+ Tip`
- `Desfazer`

Para guias complexos ainda é necessário revisar manualmente:

- `stickystart` / `label`
- `|only if`
- `|next` / `|loadguide`
- `|scenariogoal`
- `|mapmarker`
- `|script`
- aliases específicos de mapas usados internamente pelo Zygor
- textos de instrução e otimização da rota

## Comandos

- `/ozgr` — interface
- `/ozgr start [nome]`
- `/ozgr stop`
- `/ozgr pause`
- `/ozgr resume`
- `/ozgr tip TEXTO`
- `/ozgr waypoint [rótulo]`
- `/ozgr interact`
- `/ozgr undo`
- `/ozgr export`
- `/ozgr raw`
- `/ozgr clear`
- `/ozgr status`
- `/ozgr help`

## SavedVariables

Os dados são salvos em:

`WTF/Account/<CONTA>/SavedVariables/OpenZygorGuideRecorder.lua`

O WoW só persiste o arquivo de SavedVariables de forma confiável ao sair do jogo ou usar `/reload`.

## Estrutura do projeto

- `OpenZygorGuideRecorder.toc` — manifesto do addon
- `Core.lua` — namespace, banco e sessões
- `Util.lua` — helpers de mapa, quest, NPC e formatação
- `Recorder.lua` — captura de eventos do WoW
- `Exporter.lua` — geração do esqueleto Zygor
- `UI.lua` — janela do recorder e exportador
- `Slash.lua` — comandos `/ozgr`

## Limitações conhecidas do MVP

### 1. Objetivos de quest

O addon registra alterações de progresso e consolida cada objetivo na exportação. A coordenada escolhida tende a ser a primeira posição em que houve progresso. Para rotas muito precisas, revise o waypoint.

### 2. Objetos do mundo

A API nem sempre expõe um ID de GameObject de forma útil ao addon. Nesses casos o exporter pode gerar uma instrução genérica em vez de `click Objeto` com identificação completa.

### 3. Gossip

O addon tenta observar `C_GossipInfo.SelectOption` e relacionar o `gossipOptionID` com as opções exibidas. Fluxos especiais do cliente ou addons que alterem a interação podem impedir a captura perfeita.

### 4. Mapas Zygor

Os exemplos fornecidos usam nomes como `Eversong Woods M/0`. O cliente do WoW pode retornar apenas `Eversong Woods`. Por isso aliases específicos do Zygor ainda precisam ser revisados no texto exportado.

### 5. Addon sandbox

Addons do WoW não podem escrever arbitrariamente um `.lua` na pasta de AddOns enquanto o jogo está rodando. A exportação é exibida numa caixa de texto para cópia e os dados brutos ficam em SavedVariables.

## Exemplo de exportação

```lua
local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end

ZygorGuidesViewer.GuideMenuTier = "SHA"

ZygorGuidesViewer:RegisterGuide("Leveling Guides\\Custom\\Open Zygor Guide Recorder\\Minha Rota",{
author="Open Zygor Guide Recorder",
description="Recorded with Open Zygor Guide Recorder on WoW 12.1.0.",
},[[
step
talk Example NPC##123456
accept Example Quest##98765 |goto Example Zone/0 42.12,55.81
]])
```

## Próximas evoluções recomendadas

- Editor visual de steps dentro do jogo
- Sistema de aliases `mapID -> nome Zygor`
- Transformação manual de eventos em `sticky steps`
- Editor de condições `|only if`
- Marcadores de `click`, `clicknpc`, `collect`, `use`, `fpath` e `mapmarker`
- Sessões múltiplas navegáveis pela UI
- Exportador de projeto para um app desktop externo
- Otimizador de rota com reordenação de passos
