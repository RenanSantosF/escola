# Chave dos APKs de TESTE

`apk_teste.jks` assina só os **APKs de teste** gerados pelo GitHub Actions
(`.github/workflows/apk.yml`). Senha `android`, apelido `androiddebugkey`.

- O APK de teste é um app SEPARADO (`com.recreio.minhavidanaescola.teste`,
  "Recess Club Teste"): o jogo baixado da Play Store é assinado pelo Google e
  nenhum APK de fora instala por cima dele. Assim os dois ficam lado a lado.
- A chave é fixa para que cada APK de teste novo instale **por cima** do anterior
  (sem desinstalar e sem perder o jogo salvo do app de teste).
- **Não** é a chave da Play Store. O `.aab` da loja é assinado com a chave de
  upload (`recess-club-upload.keystore`), que fica só com o dono do jogo.
