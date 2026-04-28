- use headscale (hosted central on IONOS-VPS2) to have a site-2-site VPN that interconnects everything
- connect Thulin and Roisin node to the site

- Déployer Coolify via Nix comme PaaS self-hosted pour publier des projets Git sur *.theau.net, avec intégration d’Authelia via Traefik/Caddy ForwardAuth pour protéger les apps ou l’interface d’administration.
Héberger une instance Wikipédia locale afin de disposer d’une base de connaissances consultable hors ligne sur le réseau interne.


- Déployer un gestionnaire Git self-hosted pour centraliser, versionner et documenter mes projets personnels directement sur mon infrastructure.


- Intégrer Prowlarr pour C411 dans la stack média existante, avec connexion à Jellyseerr et à l’environnement qBittorrent + Gluetun pour automatiser la recherche et le téléchargement via VPN.


- Héberger un serveur SMTP interne dédié à l’envoi de mails d’état, d’alertes et de notifications pour les services auto-hébergés.


- Remplacer Filebrowser par Nextcloud afin de proposer une solution plus complète de partage, synchronisation et gestion collaborative des fichiers.


- Remplacer le fonctionnement propriétaire des TP-Link Deco M5 par une configuration OpenWrt avancée, avec les deux bornes utilisées comme points d’accès Wi-Fi reliés en Ethernet backhaul. L’objectif est de mettre en place un SSID unique avec attribution dynamique des clients à différents VLANs selon le mot de passe utilisé, via PPSK/MPSK et hostapd, tout en conservant une couverture Wi-Fi homogène et un roaming facilité entre les deux points d’accès. La solution nécessite un routeur/firewall compatible VLAN, un éventuel switch manageable, ainsi qu’une configuration 802.1Q cohérente entre le routeur, le switch et les points d’accès.

