=head1 NAME

Badger::Changes - Summary of changes in the Badger toolkit

=head1 CHANGES

=head2 Version 0.04

Moved a whole bunch of stuff out of Badger::Class into Badger::Class::*

Added Badger::Class::Config

Added hash() to Badger::Methods and hash_methods to Badger::Class

=head2 Version 0.03

Added delegate loaders to L<Badger>.  This provides some semantic sugar
for loading a bunch of different C<Badger::*> modules in one go.

    use Badger
        Filesystem  => 'FS $Bin',
        Codecs      => 'storable base64',
        Debug       => {
            modules => 'My::Module',
        };

Added L<different()|Badger::Test::Manager/different()> to 
L<Badger::Test::Manager>.

Added L<textlike()|Badger::Utils/textlike()> to L<Badger::Utils>

Added the L<overload|Badger::Class/overload>
L<as_text|Badger::Class/as_text> and 
L<is_true|Badger::Class/is_true> import hooks and related method to
L<Badger::Class>.  These delegate to the C<overload> module.

Added the L<print|Badger::Filesystem::File/print()> method to 
L<Badger::Filesystem::File>.

Added support for 
L<dynamic root directories|Badger::Filesystem::Virtual/"virtual root directories">
to L<Badger::Filesystem::Virtual>.

Added the L<defaults|Badger::Class/defaults> and L<aliases|Badger::Class/aliases>
hooks to L<Badger::Class>, implemented by L<Badger::Class::Defaults> and 
L<Badger::Class::Aliases>, respectively.  There are still experimental.

Fixed up some stat handling in L<Badger::Filesystem> to help with subclassing
in L<Badger::Filesystem::Virtual>

Mr T pities the fool that attempts to builds a production system based on
Badger version 0.03 without first evaluating it carefully and reading the
documentation.

=head2 Version 0.02

L<Badger::Class> got the L<vars|Badger::Class/vars()> method and hook
for declaring and defining variables.

L<Badger::Utils> gained the ability to load and export functions from 
L<Scalar::Util>, L<List::Util>, L<List::MoreUtils>, L<Hash::Util> and
L<Digest::MD5>.

Various documentation updates.

Mr T admires the tenacity of anyone attempting to build a production system
based on Badger v0.02 and hopes they have a thorough test suite.

=head2 Version 0.01

This was the first release version. 

Mr T pities the fool who builds a production system based on Badger v0.01.

=head1 AUTHOR

Andy Wardley  E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut