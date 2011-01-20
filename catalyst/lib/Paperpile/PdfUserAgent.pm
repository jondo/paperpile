
# Copyright 2009, 2010 Paperpile
#
# This file is part of Paperpile
#
# Paperpile is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Paperpile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.  You should have
# received a copy of the GNU Affero General Public License along with
# Paperpile.  If not, see http://www.gnu.org/licenses.


#
# A subclass of LWP::UserAgent that overrides redirect_ok in order to provide
# status update messages for the PDF crawler to indicate URLs immediately after
# a redirect signal is received. Makes the PDF download status messages feel
# a bit more snappy.
#

package Paperpile::PdfUserAgent;

use base 'LWP::UserAgent';

sub redirect_ok {
    my $self = shift;
    my $request = shift;

    return 0 if ($request->method eq 'POST');

    # Set a new status message based on the redirect destination URL.
    my $domain = $self->crawler->_short_domain($request->url);
    Paperpile::Utils->update_job_info( $self->crawler->jobid, 'msg', "Fetching from $domain...", "PDF download canceled" );

    return 1;
}

sub crawler {
    # Stores a reference to the crawler object.
    my $self = shift;
    my $crawler = shift;
    
    $self->{_crawler} = $crawler if (defined $crawler);
    return $self->{_crawler};
}

1;
