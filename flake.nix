{
  description = "MPK programming environment.";


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    saber-overlay.url = "github:saber-hq/saber-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, saber-overlay, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; } // saber-overlay.packages.${system};
    in
    {
      devShell = pkgs.stdenvNoCC.mkDerivation {
        name = "devshell";
        buildInputs = with pkgs; [
          move-cli-address32
          nodePackages.nodemon
        ];
      };
    }
  );
}
