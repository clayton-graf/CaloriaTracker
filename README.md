# CaloriaTracker Drawer

Projeto Xcode UIKit com menu lateral (drawer), sem servidor e com dados locais persistidos em JSON no aparelho.

## Abrir no Xcode
1. Abra `CaloriaTracker.xcodeproj`
2. Em `Signing & Capabilities`, escolha seu `Team`
3. Se quiser instalar no iPhone, ajuste `PRODUCT_BUNDLE_IDENTIFIER`
4. Rode no Simulator ou no aparelho

## Observações
- Esta base usa UIKit programático para evitar os problemas de layout da barra inferior.
- Os dados de alimentos, lançamentos e metas são salvos localmente em disco.
- A exclusão via swipe foi traduzida para **Excluir**.
