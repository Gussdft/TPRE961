# Prompt pour Claude Design — Support de soutenance MSPR TPRE961

> Copie-colle le bloc ci-dessous dans Claude (avec la compétence de création de présentation / design).
> Joins si possible les 4 images du dossier `livrables/` : `Schema_architecture_TPRE961.png`,
> et tes captures `make status`, page Odoo, `PLAY RECAP`.

---

Crée une présentation PowerPoint (.pptx) **professionnelle et élégante** de **16 slides**, en **français**, format 16:9 large.

## Contexte
Soutenance orale d'une certification "Expert en Informatique et Système d'Information" (RNCP 35584), MSPR Bloc 2 — gestion de projet d'infrastructure. Sujet : **un Proof of Concept déployant l'ERP Odoo sur un cluster Kubernetes (K3s), 100 % automatisé par Infrastructure as Code (Terraform + Ansible)**, pour la société fictive **COGIP** et son client **Tesker**. Durée : 20 minutes. **Public mixte : profils techniques ET non-techniques** — reste clair, évite le jargon non expliqué.

Équipe (3 personnes) : **Augustin DUFETELLE** (chef de projet / applicatif), **Victor LESCOUTRE** (infrastructure & automatisation), **Yvan DANJOU** (qualité / réseau).

## Direction artistique
- **Palette** (à respecter) : bleu marine profond `#16284A` / `#1F3864` (dominante), bleu `#2E75B6` (secondaire), cyan `#3FA7D6` (accent), fonds clairs `#EEF3FA` et blanc. Texte foncé `#1A1A1A`, gris `#5B6B7F`.
- **Structure "sandwich"** : slides de titre et de conclusion sur **fond marine sombre**, slides de contenu sur **fond clair**.
- **Motif récurrent** : numéro de section dans une **pastille ronde bleue** en haut à gauche, à côté du titre. Cartes à coins arrondis avec légère ombre et **barre d'accent latérale** colorée. Pas de trait décoratif sous les titres (cliché à éviter).
- **Typo** : titres en police à caractère (ex. Trebuchet MS / Georgia, 32–44 pt), corps en police nette (ex. Calibri, 14–16 pt). Fort contraste de taille titre/corps.
- **Chaque slide a un élément visuel** (carte, icône en cercle coloré, stat géante, image). Pas de slide "titre + puces" nue. Aligne à gauche le corps de texte, centre uniquement les titres.

## Contenu slide par slide
1. **Titre** (fond sombre) : « Déployer un ERP sur Kubernetes » + sous-titre « PoC : Odoo sur un cluster K3s, 100 % Infrastructure as Code ». Mentionne « MSPR Bloc 2 · RNCP 35584 · TPRE961 », « Société COGIP — Client Tesker », les 3 noms, et « Soutenance : __/__/2026 ».
2. **Contexte & besoin** : COGIP édite des ERP, a gagné un contrat avec Tesker (véhicules électriques) et externalise son infra. Besoin : solution **évolutive, résiliente aux pannes, reproductible (Plan de Reprise d'Activité)**. Présente ces 3 besoins en cartes.
3. **Objectif du PoC** : déployer Odoo sur Kubernetes, automatisé et reproductible. 4 **stats géantes** : `3` nœuds (1 control-plane + 2 workers), `100 %` Infrastructure as Code, `1` commande (`make all`), `HTTPS` (Ingress odoo.cogip.local).
4. **Équipe & méthode agile** : 3 cartes membres avec rôles ; méthode **Scrum hybride + Kanban** (À faire → En cours → Revue technique → Terminé), points quotidiens, revue technique collective, versionnement **Git** (secrets exclus).
5. **Planning & jalons** : frise de 5 jalons — J1 Cadrage (22/05), J2 Infra Terraform (28/05), J3 Cluster K3s (04/06), J4 Odoo HTTPS (10/06), J5 Soutenance (16/06).
6. **Choix technologiques** : 4 cartes justifiées — **K3s** (Traefik + ServiceLB intégrés, léger pour 8 Go de RAM), **Multipass/QEMU** (3 VMs Ubuntu ARM64 locales, coût nul), **Terraform + Ansible** (IaC), **images officielles Odoo 17 + PostgreSQL 16** (chart Bitnami écarté car déprécié → ImagePullBackOff).
7. **Architecture** : grande image `Schema_architecture_TPRE961.png` (du poste Mac → K3s → NFS → Ingress HTTPS), légende courte.
8. **Déploiement automatisé** : flux en 4 étapes numérotées — Terraform (VMs) → Ansible Cluster (K3s + NFS) → Ansible Plateforme (Helm : provisioner NFS + cert-manager) → Ansible Odoo (PostgreSQL + Odoo + Ingress). Bandeau : « `make all` reconstruit tout sans action manuelle ».
9. **Démonstration** (fond sombre) : « Le cluster en direct » — 3 points : état du cluster, Odoo dans le navigateur, reconstruction automatisée.
10. **Preuve : cluster opérationnel** : capture `make status` (3 nœuds Ready, pods Running) + capture `PLAY RECAP` (failed=0, unreachable=0) + carte explicative.
11. **Preuve : Odoo accessible** : capture de l'interface Odoo sur `https://odoo.cogip.local` + carte « exposé en HTTPS via Traefik, cert-manager ».
12. **Pilotage & inclusion** : aperçu du tableau de bord prestataires (SLA, coûts, pénalités, graphiques) + carte « démarche inclusive » (accueil handicap, communication multiculturelle, collaboration à distance, cohésion).
13. **Difficultés & solutions** : tableau 2 colonnes — 8 Go de RAM / repli nœud unique ; Bitnami déprécié / images officielles ; « No route to host » / amorçage ARP ; inventaire JSON vide / fichier temporaire ; callback yaml supprimé / result_format=yaml.
14. **Plan de Reprise d'Activité** : deux blocs — `make down` (détruit, simule un incident) et `make all` (reconstruit à l'identique). Message fort : « Aucune action manuelle, état identique garanti par le code — c'est le PRA demandé par Tesker. »
15. **Vers la production** : 4 cartes — cluster managé HA (Kapsule/GKE/AKS), stockage CSI répliqué, TLS Let's Encrypt + LoadBalancer managé, sécurité/exploitation (secrets en coffre, sauvegardes, observabilité).
16. **Conclusion** (fond sombre) : PoC fonctionnel, reproductible (PRA en une commande), conduit en agilité. Termine par « Merci de votre attention — Questions ? » et les 3 noms.

## Exigences
- Insère les captures d'écran fournies aux slides 7, 10, 11, 12 (sans déformation, sans débordement des bords).
- Pas de fautes, pas de texte coupé, marges ≥ 1,3 cm, gabarit cohérent d'une slide à l'autre.
- Rends le fichier `.pptx` final téléchargeable.
