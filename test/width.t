use FindBin '$Bin';
use lib $Bin;
use TestYAMLTests tests => 5;

my @a = split /\s+/, 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc sed sagittis nisi, 
vitae elementum est. Vestibulum interdum eros ut neque viverra, aliquet euismod justo aliquam. Mauris
nibh nibh, scelerisque id velit eu, cursus pharetra nisi. Maecenas at tortor ac eros auctor euismod
nec id sapien. Donec eu faucibus nunc. Phasellus sagittis varius nibh a dapibus.';

sub _ {join ' ', @a[@_]}
sub ___ {
  is Dump([{_(0,1)=>_(2..14),_(15)=>{_(16)=>_(17..24),_(25..27)=>{_(26)=>_(27..44),_(45,46)=>_(47,48),_(49)=>_(50..54)}}}]),
  $_[1], 'Dumped with width ' . $_[0]
}

___('undef', <<'xxx'); # default of libyaml is 80
---
- Lorem ipsum: dolor sit amet, consectetur adipiscing elit. Nunc sed sagittis nisi,
    vitae elementum est.
  Vestibulum:
    Mauris nibh nibh,:
      Donec eu: faucibus nunc.
      Phasellus: sagittis varius nibh a dapibus.
      nibh: nibh, scelerisque id velit eu, cursus pharetra nisi. Maecenas at tortor
        ac eros auctor euismod nec id sapien.
    interdum: eros ut neque viverra, aliquet euismod justo aliquam.
xxx

___(1, <<'xxx'); # width <= 2* indent is changed to default in libyaml
---
- Lorem ipsum: dolor sit amet, consectetur adipiscing elit. Nunc sed sagittis nisi,
    vitae elementum est.
  Vestibulum:
    Mauris nibh nibh,:
      Donec eu: faucibus nunc.
      Phasellus: sagittis varius nibh a dapibus.
      nibh: nibh, scelerisque id velit eu, cursus pharetra nisi. Maecenas at tortor
        ac eros auctor euismod nec id sapien.
    interdum: eros ut neque viverra, aliquet euismod justo aliquam.
xxx

___($YAML::XS::Width = -1, <<'xxx');
---
- Lorem ipsum: dolor sit amet, consectetur adipiscing elit. Nunc sed sagittis nisi, vitae elementum est.
  Vestibulum:
    Mauris nibh nibh,:
      Donec eu: faucibus nunc.
      Phasellus: sagittis varius nibh a dapibus.
      nibh: nibh, scelerisque id velit eu, cursus pharetra nisi. Maecenas at tortor ac eros auctor euismod nec id sapien.
    interdum: eros ut neque viverra, aliquet euismod justo aliquam.
xxx

___($YAML::XS::Width = 60, <<'xxx');
---
- Lorem ipsum: dolor sit amet, consectetur adipiscing elit. Nunc
    sed sagittis nisi, vitae elementum est.
  Vestibulum:
    Mauris nibh nibh,:
      Donec eu: faucibus nunc.
      Phasellus: sagittis varius nibh a dapibus.
      nibh: nibh, scelerisque id velit eu, cursus pharetra nisi.
        Maecenas at tortor ac eros auctor euismod nec id sapien.
    interdum: eros ut neque viverra, aliquet euismod justo aliquam.
xxx
___($YAML::XS::Width = 10, <<'xxx');
---
- Lorem ipsum: dolor
    sit amet,
    consectetur
    adipiscing
    elit. Nunc
    sed sagittis
    nisi, vitae
    elementum
    est.
  Vestibulum:
    Mauris nibh nibh,:
      Donec eu: faucibus
        nunc.
      Phasellus: sagittis
        varius
        nibh
        a dapibus.
      nibh: nibh,
        scelerisque
        id velit
        eu,
        cursus
        pharetra
        nisi.
        Maecenas
        at tortor
        ac eros
        auctor
        euismod
        nec
        id sapien.
    interdum: eros
      ut neque
      viverra,
      aliquet
      euismod
      justo
      aliquam.
xxx
