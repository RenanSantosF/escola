# Chave dos APKs de TESTE

`apk_teste.jks` assina só os **APKs de teste** gerados pelo GitHub Actions
(`.github/workflows/apk.yml`). Senha `android`, apelido `androiddebugkey`.

- Ela é fixa para que cada APK novo instale **por cima** do anterior no celular
  (sem desinstalar e sem perder o jogo salvo).
- **Não** é a chave da Play Store. O `.aab` da loja é assinado com a chave de
  upload (`recess-club-upload.keystore`), que fica só com o dono do jogo.
