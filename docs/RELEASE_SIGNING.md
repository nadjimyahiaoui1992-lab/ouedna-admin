# Publication signée — Ouedna Admin 2

L’application indépendante utilise le package Android `com.ouedna.admin.v2`. Sa clé de release ne doit jamais être ajoutée au dépôt ni transmise dans un message.

Le workflow `.github/workflows/release.yml` restaure la clé uniquement pendant la construction à partir des secrets GitHub suivants : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_STORE_PASSWORD` et `ANDROID_KEY_PASSWORD`.

Pour publier une version, créer puis pousser un tag au format `admin-v2.0.0`. Le pipeline vérifie le formatage, l’analyse Flutter, les tests, la signature des APK par ABI et crée la release GitHub correspondante.
