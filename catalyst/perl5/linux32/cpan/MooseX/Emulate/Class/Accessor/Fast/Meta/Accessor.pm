package MooseX::Emulate::Class::Accessor::Fast::Meta::Accessor;

use Moose;

extends 'Moose::Meta::Method::Accessor';

sub _generate_accessor_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        my $self = shift;
        $attr->set_value($self, $_[0]) if scalar(@_) == 1;
        $attr->set_value($self, [@_]) if scalar(@_) > 1;
        $attr->get_value($self);
    };
}

sub _generate_writer_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        my $self = shift;
        $attr->set_value($self, $_[0]) if scalar(@_) == 1;
        $attr->set_value($self, [@_]) if scalar(@_) > 1;
    };
}

# FIXME - this is shite, but it does work...
sub _generate_accessor_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval "sub {
        my \$self = shift;
        \$self->{'$attr_name'} = \$_[0] if scalar(\@_) == 1;
        \$self->{'$attr_name'} = [\@_] if scalar(\@_) > 1;
        \$self->{'$attr_name'};
    }";
    confess "Could not generate inline accessor because : $@" if $@;

    return $code;
}

{
    my $meta = __PACKAGE__->meta;
    $meta->add_method(_generate_writer_method_inline => $meta->get_method('_generate_accessor_method_inline'));
}

no Moose;

1;
