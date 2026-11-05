# Konoha RP — Portail du Village Caché de la Feuille

Application de rôle-play créée pour le serveur Naruto RP. Site public hébergé via **GitHub Pages** ; **Supabase** sert aux comptes et aux données. Ce n'est pas un service officiel de Naruto.

## Adresse du site

- Accueil : https://poseid0nhorii-ai.github.io/konoha-rp/
- Portail interactif : https://poseid0nhorii-ai.github.io/konoha-rp/portal.html

## Déjà livré

- Interface de portail responsive avec navigation par sections et design personnalisé.
- Six Hokage RP : Hashirama Senju, Tobirama Senju, Taikyoku Uchiha, Kazama Senju, Akû Hyûga et **Renji Kurugane (en fonction)**.
- Hiérarchie exacte : commandement, sous-commandement, bas gradés, Sannin et Conseil du Feu ; aucun « Grand Chûnin ».
- Pages publiques : accueil, clans, registre, missions, événements, formations, documents, sections, demandes, messagerie, administration.
- Formulaires de création pour missions, annonces, événements, formations, documents, demandes et messages (après connexion Supabase).
- Validation des comptes et attribution de grades, clans et permissions par l'administrateur.
- Schéma SQL avec politiques de sécurité RLS (Row Level Security).
- ANBU non exposée publiquement ; ses membres doivent être enregistrés dans la table privée `section_memberships`.

## Activation des vrais comptes (à faire une fois)

1. Crée un projet gratuit sur https://supabase.com/dashboard.
2. Ouvre **SQL Editor**, copie le contenu de `database/schema.sql` et exécute-le dans le projet.
3. Dans **Project Settings → API** (ou **Connect** suivant ton interface), copie l'URL du projet et la clé publique `anon` / `publishable`.
4. Ouvre **config.js** dans GitHub et remplace les deux valeurs vides :
   ```js
   window.KONOHA_CONFIG = {
     supabaseUrl: "https://TON-PROJET.supabase.co",
     supabaseAnonKey: "TA_CLE_PUBLIQUE_ANON"
   };
   ```
   **Ne copie jamais de clé `service_role`, `secret` ou de mot de passe dans GitHub** : le dépôt est public.
5. Dans **Supabase → Authentication → URL Configuration**, ajoute
   `https://poseid0nhorii-ai.github.io/konoha-rp/portal.html` aux URLs de redirection autorisées.
6. Dans **Authentication → Providers → Email**, règle la confirmation des e-mails selon tes besoins, puis inscris ton compte administrateur sur le portail.
7. Pour attribuer le **premier** compte administrateur, retourne dans **SQL Editor** et exécute (en remplaçant l'adresse) :
   ```sql
   update public.profiles set role='admin', approved=true
   where id=(select id from auth.users where email='TON_EMAIL_ADMIN');
   ```
8. Recharge le portail, connecte-toi et ouvre **Administration**. Tu peux maintenant approuver les profils et attribuer les grades et droits.

**Attention** : ce SQL donne des droits très élevés. Vérifie impérativement l'adresse e-mail et ne communique jamais de mot de passe dans un salon public.

## Inviter de nouveaux utilisateurs directement depuis l'administration

L'invitation par e-mail d'un nouveau compte nécessite une **Edge Function** pour garder la clé secrète côté Supabase. Le code est dans `supabase/functions/admin-invite/index.ts`. Après avoir installé le CLI Supabase sur ton PC et associé ton projet, exécute :
```sh
supabase functions deploy admin-invite
```
La fonction vérifie côté serveur que l'appelant est administrateur, puis invite l'adresse e-mail demandée. Sans cette étape, les joueurs peuvent s'inscrire eux-mêmes et attendre ta validation.

## Sécurité et limites

- **GitHub Pages est public** : aucun dossier ANBU ni donnée confidentielle ne doit être placé dans le HTML, JS ou les fichiers statiques.
- Les règles d'accès sont implémentées côté **Supabase RLS**, pas par un bouton invisible.
- Un rôle technique `admin` est indépendant du grade RP `Hokage`.
- Les fiches de comptes non validés ne sont pas visibles au public.
- La messagerie est privée entre expéditeur et destinataire grâce à RLS.
- Les données privées des sections ne disposent pas encore de leur interface complète (dossiers médicaux, enquêtes, missions ANBU). **Ne pas les publier dans des pages publiques**.
- Les invitations e-mail nécessitent le déploiement séparé de la fonction serveur.
- Les modules complexes (workflow complet de promotion, signatures, comptes rendus avec pièces jointes, historique de modification, calendrier récurrent et passeports numériques) sont prévus pour des itérations supplémentaires.

## Modifier le site

Le portail peut être ouvert en direct depuis GitHub Pages. Le fichier `index.html` est la page d'accueil, `portal.html` le portail, `portal.css` son style et `portal.js` son code. Les modifications de GitHub sur la branche `main` sont publiées automatiquement via GitHub Pages.

Pour vérifier un bug, ouvre F12 → Console ; n'envoie pas de jetons privés, mots de passe ou clés secrètes.
