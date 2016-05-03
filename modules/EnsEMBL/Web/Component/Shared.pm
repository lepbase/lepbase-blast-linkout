=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 MODIFICATIONS

Copyright [2014-2015] University of Edinburgh

All modifications licensed under the Apache License, Version 2.0, as above.

=cut

package EnsEMBL::Web::Component::Shared;

use strict;

sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $species     = $hub->species;
  my $table       = $self->new_twocol;
  my $page_type   = ref($self) =~ /::Gene\b/ ? 'gene' : 'transcript';
  my $description = $object->gene_description;
     $description = '' if $description eq 'No description';
  my $show        = $hub->get_cookie_value('toggle_transcripts_table') eq 'open';
  my $button      = sprintf('<a rel="transcripts_table" class="button toggle no_img _slide_toggle set_cookie %s" href="#" title="Click to toggle the transcript table">
    <span class="closed">Show transcript table</span><span class="open">Hide transcript table</span>
    </a>',
    $show ? 'open' : 'closed'
  );

  if ($description) {

    my ($url, $xref) = $self->get_gene_display_link($object->gene, $description);

    if ($xref) {
      $xref        = $xref->primary_id;
      $description =~ s|$xref|<a href="$url" class="constant">$xref</a>|;
    }

    $table->add_row('Description', $description);
  }

  my $location    = sprintf '%s:%s-%s', $object->seq_region_name, $object->seq_region_start, $object->seq_region_end;

  my (@syn_matches, $syns_html, $about_count);
  push @syn_matches,@{$object->get_database_matches()};

  my $gene = $page_type eq 'gene' ? $object->Obj : $object->gene;

  $self->add_phenotype_link($gene, $table); #function in mobile plugin

  my %unique_synonyms;
  my $c=0;
  foreach (@{$object->get_similarity_hash(0, $gene)}) {
    next unless $_->{'type'} eq 'PRIMARY_DB_SYNONYM';
    my $id   = $_->display_id;
    my %syns = %{$self->get_synonyms($id, @syn_matches) || {}};
    foreach (keys %syns) {
      $unique_synonyms{$_}++;
    }
  }
  if (%unique_synonyms) {
    my $syns = join ', ', keys %unique_synonyms;
    $syns_html = "<p>$syns</p>";
    $table->add_row('Synonyms', $syns_html);
  }

  my $seq_region_name  = $object->seq_region_name;
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;

  my $location_html = sprintf(
    '<a href="%s" class="constant mobile-nolink">%s: %s-%s</a> %s.',
    $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $location,
    }),
    $self->neat_sr_name($object->seq_region_type, $seq_region_name),
    $self->thousandify($seq_region_start),
    $self->thousandify($seq_region_end),
    $object->seq_region_strand < 0 ? ' reverse strand' : 'forward strand'
  );

  # alternative (Vega) coordinates
  if ($object->get_db eq 'vega') {
    my $alt_assemblies  = $hub->species_defs->ALTERNATIVE_ASSEMBLIES || [];
    my ($vega_assembly) = map { $_ =~ /VEGA/; $_ } @$alt_assemblies;

    # set dnadb to 'vega' so that the assembly mapping is retrieved from there
    my $reg        = 'Bio::EnsEMBL::Registry';
    my $orig_group = $reg->get_DNAAdaptor($species, 'vega')->group;

    $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');

    my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly

    # link to Vega if there is an ungapped mapping of whole gene
    if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
      my $l = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;

      $location_html .= ' [<span class="small">This corresponds to ';
      $location_html .= sprintf(
        '<a href="%s" target="external" class="constant">%s-%s</a>',
        $hub->ExtURL->get_url('VEGA_CONTIGVIEW', $l),
        $self->thousandify($alt_slices->[0]->start),
        $self->thousandify($alt_slices->[0]->end)
      );

      $location_html .= " in $vega_assembly coordinates</span>]";
    } else {
      $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
    }

    $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
  }

  $location_html = "<p>$location_html</p>";

  my $insdc_accession = $self->object->insdc_accession if $self->object->can('insdc_accession');
  if ($insdc_accession) {
    $location_html .= "<p>$insdc_accession</p>";
  }

  if ($page_type eq 'gene') {
    # Haplotype/PAR locations
    my $alt_locs = $object->get_alternative_locations;

    if (@$alt_locs) {
      $location_html .= '
        <p> This gene is mapped to the following HAP/PARs:</p>
        <ul>';

      foreach my $loc (@$alt_locs) {
        my ($altchr, $altstart, $altend, $altseqregion) = @$loc;

        $location_html .= sprintf('
          <li><a href="/%s/Location/View?l=%s:%s-%s" class="constant mobile-nolink">%s : %s-%s</a></li>',
          $species, $altchr, $altstart, $altend, $altchr,
          $self->thousandify($altstart),
          $self->thousandify($altend)
        );
      }

      $location_html .= '
        </ul>';
    }
  }

  my $gene = $object->gene;

  #text for tooltips
  my $gencode_desc    = qq(The GENCODE set is the gene set for human and mouse. <a href="/Help/Glossary?id=500" class="popup">GENCODE Basic</a> is a subset of representative transcripts (splice variants).);
  my $gene_html       = '';
  my $transc_table;

  if ($gene) {
    my $transcript  = $page_type eq 'transcript' ? $object->stable_id : $hub->param('t');
    my $transcripts = $gene->get_all_Transcripts;
    my $count       = @$transcripts;
    my $plural      = 'transcripts';
    my $splices     = 'splice variants';
    my $action      = $hub->action;
    my %biotype_rows;

    my $trans_attribs = {};
    my $trans_gencode = {};

    foreach my $trans (@$transcripts) {
      foreach my $attrib_type (qw(CDS_start_NF CDS_end_NF gencode_basic TSL appris)) {
        (my $attrib) = @{$trans->get_all_Attributes($attrib_type)};
        next unless $attrib;
        if($attrib_type eq 'gencode_basic' && $attrib->value) {
          $trans_gencode->{$trans->stable_id}{$attrib_type} = $attrib->value;
        } elsif ($attrib_type eq 'appris'  && $attrib->value) {
          ## There should only be one APPRIS code per transcript
          my $short_code = $attrib->value;
          ## Manually shorten the full attrib values to save space
          $short_code =~ s/ernative//;
          $short_code =~ s/rincipal//;
          $trans_attribs->{$trans->stable_id}{'appris'} = [$short_code, $attrib->value];
          last;
        } else {
          $trans_attribs->{$trans->stable_id}{$attrib_type} = $attrib->value if ($attrib && $attrib->value);
        }
      }
    }
    my %url_params = (
      type   => 'Transcript',
      action => $page_type eq 'gene' || $action eq 'ProteinSummary' ? 'Summary' : $action
    );

    if ($count == 1) {
      $plural =~ s/s$//;
      $splices =~ s/s$//;
    }

    if ($page_type eq 'transcript') {
      my $gene_id  = $gene->stable_id;
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Summary',
        g      => $gene_id
      });
      $gene_html .= sprintf('<p>This transcript is a product of gene <a href="%s">%s</a> %s',
        $gene_url,
        $gene_id,
        $button
      );
    }

    ## Link to other haplotype genes
    my $alt_link = $object->get_alt_allele_link;
    if ($alt_link) {
      if ($page_type eq 'gene') {
        $location_html .= "<p>$alt_link</p>";
      }
    }

    my @columns = (
       { key => 'name',       sort => 'string',  title => 'Name'          },
       { key => 'transcript', sort => 'html',    title => 'Transcript ID' },
       { key => 'bp_length',  sort => 'numeric', label => 'bp', title => 'Length in base pairs'},
       { key => 'protein',sort => 'html_numeric',label => 'Protein', title => 'Protein length in amino acids' },
       { key => 'translation',sort => 'html',    title => 'Translation ID', 'hidden' => 1 },
       { key => 'biotype',    sort => 'html',    title => 'Biotype', align => 'left' },
    );

    push @columns, { key => 'ccds', sort => 'html', title => 'CCDS' } if $species =~ /^Homo_sapiens|Mus_musculus/;

    my @rows;

    my %extra_links = (
      uniprot => { match => "^UniProt/[SWISSPROT|SPTREMBL]", name => "UniProt", order => 0 },
      refseq => { match => "^RefSeq", name => "RefSeq", order => 1 },
    );
    my %any_extras;

    foreach (map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } map { [ $_->external_name, $_->stable_id, $_ ] } @$transcripts) {
      my $transcript_length = $_->length;
      my $tsi               = $_->stable_id;
      my $protein           = '';
      my $translation_id    = '';
      my $protein_url       = '';
      my $protein_length    = '-';
      my $ccds              = '-';
      my %extras;
      my $cds_tag           = '-';
      my $gencode_set       = '-';
      my $url               = $hub->url({ %url_params, t => $tsi });
      my (@flags, @evidence);

      if (my $translation = $_->translation) {
        $protein_url    = $hub->url({ type => 'Transcript', action => 'ProteinSummary', t => $tsi });
        $translation_id = $translation->stable_id;
        $protein_length = $translation->length;
      }

      my $dblinks = $_->get_all_DBLinks;
      if (my @CCDS = grep { $_->dbname eq 'CCDS' } @$dblinks) {
        my %T = map { $_->primary_id => 1 } @CCDS;
        @CCDS = sort keys %T;
        $ccds = join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS;
      }
      foreach my $k (keys %extra_links) {
        if(my @links = grep {$_->status ne 'PRED' } grep { $_->dbname =~ /$extra_links{$k}->{'match'}/i } @$dblinks) {
          my %T = map { $_->primary_id => $_->dbname } @links;
          my $cell = '';
          my $i = 0;
          foreach my $u (map $hub->get_ExtURL_link($_,$T{$_},$_), sort keys %T) {
            $cell .= "$u ";
            if($i++==2 || $k ne 'uniprot') { $cell .= "<br/>"; $i = 0; }
          }
          $any_extras{$k} = 1;
          $extras{$k} = $cell;
        }
      }
      if ($trans_attribs->{$tsi}) {
        if (my $incomplete = $self->get_CDS_text($trans_attribs->{$tsi})) {
          push @flags, $incomplete;
        }
        if ($trans_attribs->{$tsi}{'TSL'}) {
          my $tsl = uc($trans_attribs->{$tsi}{'TSL'} =~ s/^tsl([^\s]+).*$/$1/gr);
          push @flags, $self->helptip("TSL:$tsl", $self->get_glossary_entry("TSL:$tsl").$self->get_glossary_entry('TSL'));
        }
      }

      if ($trans_gencode->{$tsi}) {
        if ($trans_gencode->{$tsi}{'gencode_basic'}) {
          push @flags, $self->helptip('GENCODE basic', $gencode_desc);
        }
      }
      if ($trans_attribs->{$tsi}{'appris'}) {
        my ($code, $key) = @{$trans_attribs->{$tsi}{'appris'}};
        my $short_code = $code ? ' '.uc($code) : '';
          push @flags, $self->helptip("APPRIS$short_code", $self->get_glossary_entry("APPRIS: $key").$self->get_glossary_entry('APPRIS'));
      }

      (my $biotype_text = $_->biotype) =~ s/_/ /g;
      if ($biotype_text =~ /rna/i) {
        $biotype_text =~ s/rna/RNA/;
      }
      else {
        $biotype_text = ucfirst($biotype_text);
      }

      $extras{$_} ||= '-' for(keys %extra_links);
      my $row = {
        name        => { value => $_->display_xref ? $_->display_xref->display_id : 'Novel', class => 'bold' },
        transcript  => sprintf('<a href="%s">%s</a>', $url, $tsi),
        bp_length   => $transcript_length,
        protein     => $protein_url ? sprintf '<a href="%s" title="View protein">%saa</a>', $protein_url, $protein_length : 'No protein',
        translation => $protein_url ? sprintf '<a href="%s" title="View protein">%s</a>', $protein_url, $translation_id : '-',
        biotype     => $self->colour_biotype($biotype_text, $_),
        ccds        => $ccds,
        %extras,
        has_ccds    => $ccds eq '-' ? 0 : 1,
        cds_tag     => $cds_tag,
        gencode_set => $gencode_set,
        options     => { class => $count == 1 || $tsi eq $transcript ? 'active' : '' },
        flags       => join('',map { $_ =~ /<img/ ? $_ : "<span class='ts_flag'>$_</span>" } @flags),
        evidence    => join('', @evidence),
      };

      $biotype_text = '.' if $biotype_text eq 'Protein coding';
      $biotype_rows{$biotype_text} = [] unless exists $biotype_rows{$biotype_text};
      push @{$biotype_rows{$biotype_text}}, $row;
    }
    foreach my $k (sort { $extra_links{$a}->{'order'} cmp
                          $extra_links{$b}->{'order'} } keys %any_extras) {
      my $x = $extra_links{$k};
      push @columns, { key => $k, sort => 'html', title => $x->{'name'}};
    }
    push @columns, { key => 'flags', sort => 'html', title => 'Flags' };

    ## Additionally, sort by CCDS status and length
    while (my ($k,$v) = each (%biotype_rows)) {
      my @subsorted = sort {$b->{'has_ccds'} cmp $a->{'has_ccds'}
                            || $b->{'bp_length'} <=> $a->{'bp_length'}} @$v;
      $biotype_rows{$k} = \@subsorted;
    }

    # Add rows to transcript table
    push @rows, @{$biotype_rows{$_}} for sort keys %biotype_rows;

    @columns = $self->table_removecolumn(@columns); # implemented in mobile plugin

    $transc_table = $self->new_table(\@columns, \@rows, {
      data_table        => 1,
      data_table_config => { bPaginate => 'false', asStripClasses => [ '', '' ], oSearch => { sSearch => '', bRegex => 'false', bSmart => 'false' } },
      toggleable        => 1,
      class             => 'fixed_width' . ($show ? '' : ' hide'),
      id                => 'transcripts_table',
      exportable        => 1
    });

    if($page_type eq 'gene') {
      $gene_html      .= $button;
    }

    $about_count = $self->about_feature; # getting about this gene or transcript feature counts

  }

  $table->add_row('Location', $location_html);

  $table->add_row( $page_type eq 'gene' ? 'About this gene' : 'About this transcript',$about_count) if $about_count;
  $table->add_row($page_type eq 'gene' ? 'Transcripts' : 'Gene', $gene_html) if $gene_html;

  ##################################
  ### BEGIN LEPBASE MODIFICATIONS...
  ##################################
    my $title = $object->stable_id;
    my $slice = $object->slice;
    my $blast_html;
    if ($page_type eq 'gene'){
    	my $seq = $slice->{'seq'} || $slice->seq(1);
      $blast_html = sequenceserver_button($title,$seq,'Gene');
    }
    else {
    	my $transcripts = $gene->get_all_Transcripts;
    	my $index = 0;
      if (@$transcripts > 1){
      	for (my $i = 0; $i < @$transcripts; $i++) {
      		$index = $i;
      		last if $title eq $transcripts->[$i]->stable_id;
      	}
      }
      my $seq = $transcripts->[$index]->seq()->seq();
      $blast_html = sequenceserver_button($title,$seq,'Transcript');
      $seq = undef;
      $seq = $transcripts->[$index]->spliced_seq();
      $blast_html .= sequenceserver_button($title,$seq,'cDNA') if $seq;
      $seq = undef;
      $seq = $transcripts->[$index]->translateable_seq();
      $blast_html .= sequenceserver_button($title,$seq,'CDS') if $seq;
      $seq = undef;
      $seq = $transcripts->[$index]->translate()->seq();
      $blast_html .= sequenceserver_button($transcripts->[$index]->stable_id,$seq,'Protein') if $seq;
    }
    $table->add_row('BLAST',$blast_html);
  ##################################
  ### ...END LEPBASE MODIFICATIONS
  ##################################

  return sprintf '<div class="summary_panel">%s%s</div>', $table->render, $transc_table ? $transc_table->render : '';
}


##################################
### BEGIN LEPBASE MODIFICATIONS...
##################################
sub sequenceserver_button {
    my ($title,$sequence,$label) = @_;
    my $button = '
        <form id="nt_blast_form_'.$label.'" target="_blank" action="http://blast.lepbase.org" method="POST">
            <input type="hidden" name="input_sequence" value=">'.$title."\n".$sequence.'">
            <a href="#" onclick="document.getElementById(\'nt_blast_form_'.$label.'\').submit();" class="button toggle no_img" style="float:left" title="Click to BLAST against Lepidoptera genes and genomes (opens a new window)">'.$label.'</a>
        </form>';

    return $button;
}
##################################
### ...END LEPBASE MODIFICATIONS
##################################
1;
