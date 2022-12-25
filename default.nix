with (import <nixpkgs> {});
mkShell {
  buildInputs = [
    postgresql_11
    redis
  ];
}
