requires "Graph" => "0";
requires "Module::Runtime" => "0";
requires "Moo" => "1.001000";
requires "Path::Tiny" => "0.018";
requires "Ref::Util" => "0";
requires "Time::Seconds" => "0";
requires "Types::Standard" => "0";
requires "namespace::autoclean" => "0";
recommends "Class::Load::XS" => "0";
recommends "Ref::Util::XS" => "0";
recommends "Type::Tiny::XS" => "0";

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "Module::Metadata" => "0";
  requires "Path::Tiny" => "0.018";
  requires "Test::More" => "0.99";
  requires "Test::Most" => "0";
  requires "Time::Piece" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CleanNamespaces" => "0.15";
  requires "Test::EOF" => "0";
  requires "Test::EOL" => "0";
  requires "Test::Kwalitee" => "1.21";
  requires "Test::MinimumVersion" => "0";
  requires "Test::More" => "0.88";
  requires "Test::NoTabs" => "0";
  requires "Test::Perl::Critic" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Pod::LinkCheck" => "0";
  requires "Test::Portability::Files" => "0";
  requires "Test::TrailingSpace" => "0.0203";
};