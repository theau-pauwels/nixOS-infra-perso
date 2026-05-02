[
  {
    name = "theau - qbit houzeau";
    publicKey = "s8hwZrzBPE8NbEbjodm52vsccAOWQxXQ6JX2YAJalAM=";
    allowedIPs = [ "10.8.0.20/32" ];
  }
  {
    name = "theau - debug";
    publicKey = "J3P21KFvcmaZzUyBat+/Ay8ptgotaz1WRkesP7nZbhA=";
    allowedIPs = [ "10.8.0.2/32" ];
  }
  {
    name = "theau - desktop-kot";
    publicKey = "R/RZmlBLFjoO55NjMKsEU4kres2xZtsUyyFOKx/brRM=";
    allowedIPs = [ "10.8.0.3/32" ];
  }
  {
    name = "theau - phone";
    publicKey = "6CZeHIdefBY+Bc2Nz8+ZT8xtO1JvYxbFVPsn3WOTaUY=";
    allowedIPs = [ "10.8.0.4/32" ];
  }
  {
    name = "theau - laptop-msi";
    publicKey = "K2Tf2kN595HM/Xg/1noywGjSrygpZjBc1b9mFWqSWmQ=";
    allowedIPs = [ "10.8.0.5/32" ];
  }
  {
    name = "magellan - random [05-apr-2026]";
    publicKey = "Foo4gSN0shV6DUhXDjA3tUF0NK0tXU/U7RxL6MjloxM=";
    allowedIPs = [ "10.8.0.6/32" ];
  }
  {
    name = "jellyfin-kot";
    publicKey = "W9CIfBfL/9iYCdV1pDlOpi76jLKyLFBh1Ssd3sAMoj8=";
    allowedIPs = [ "10.8.0.21/32" ];
  }
  {
    name = "seedbox-kot";
    publicKey = "QAwl8Yaq8Ncq/8YiBvos+muSaZI6kPM/7Vga/B90VHg=";
    allowedIPs = [ "10.8.0.22/32" ];
  }
  {
    name = "storage-kot";
    publicKey = "eAzR2K1KCpY2jMy8IBzgUurvLx4Jg1vqklIGbivngwA=";
    allowedIPs = [ "10.8.0.23/32" ];
  }
  {
    name = "mom-edge site gateway skeleton";
    enabled = false;
    # Placeholder public key. Replace with the real Mom edge public key before
    # enabling this peer in the active VPS bundle.
    publicKey = "/L0CT1WX66/Su2H2IH6mP530Ynbrc3rd5gex3IwAKS8=";
    allowedIPs = [
      "10.8.0.30/32"
      "10.10.10.0/24"
    ];
  }
  {
    name = "dad-edge site gateway skeleton";
    enabled = false;
    # Placeholder public key. Replace with the real Dad edge public key before
    # enabling this peer in the active VPS bundle.
    publicKey = "NJIsf3irx6gRKwldXK59mFBeXKm8/yMQfVm1G2wJwWQ=";
    allowedIPs = [
      "10.8.0.40/32"
      "10.7.10.0/24"
    ];
  }
]
