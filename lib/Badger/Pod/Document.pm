#========================================================================
#
# Badger::Pod::Document
#
# DESCRIPTION
#   Object respresenting a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Document;

use Badger::Pod 'POD';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    filesystem  => 'File',
    get_methods => 'text file name',
    constants   => 'SCALAR',
    constant    => {
#        TEXT_NAME => '<input text>',
        TEXT_NAME => '',
    },
    messages   => {
        no_input => 'No text or file parameter specified',
    };


sub init {
    my ($self, $config) = @_;
    my ($text, $file, $name, $nodes);
    
    if ($file = $config->{ file }) {
        $file = File($file);
        $self->{ file } = $file;
        $self->{ text } = $file->text;
        $self->{ name } = $config->{ name } || $file->name;
    }
    elsif ($text = $config->{ text }) {
        $self->{ text } = ref $text eq SCALAR
            ? $$text 
            :  $text . '';  # force stringification of text objects
        $self->{ name } = $config->{ name } || $self->TEXT_NAME;
    }
    else {
        return $self->error_msg('no_input');
    }

    # augment and store the config so we can pass it to parsers later
    $config->{ name } = $self->{ name };
    $self->{ config } = $config;
    
    return $self;
}

sub blocks {
    my $self = shift;
    $self->{ blocks } 
        ||= POD->block_parser($self->{ config })
               ->parse(@$self{ qw( text name ) });
}

sub model {
    my $self = shift;
    $self->{ model } 
        ||= POD->model_parser($self->{ config })
               ->parse(@$self{ qw( text name ) });
}


1;

__END__

