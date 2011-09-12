# coding: utf-8
$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

# w3c test suite: http://www.w3.org/TR/rdf-testcases/

describe "RDF::RDFXML::Reader" do
  before :each do
    @reader = RDF::RDFXML::Reader.new(StringIO.new(""))
  end

  it_should_behave_like RDF_Reader

  context "discovery" do
    {
      "rdf" => RDF::Reader.for(:rdf),
      "rdfxml" => RDF::Reader.for(:rdfxml),
      "etc/foaf.xml" => RDF::Reader.for("etc/foaf.xml"),
      "etc/foaf.rdf" => RDF::Reader.for("etc/foaf.rdf"),
      "foaf.xml" => RDF::Reader.for(:file_name      => "foaf.xml"),
      "foaf.rdf" => RDF::Reader.for(:file_name      => "foaf.rdf"),
      ".xml" => RDF::Reader.for(:file_extension => "xml"),
      ".rdf" => RDF::Reader.for(:file_extension => "rdf"),
      "application/xml" => RDF::Reader.for(:content_type   => "application/xml"),
      "application/rdf+xml" => RDF::Reader.for(:content_type   => "application/rdf+xml"),
    }.each_pair do |label, format|
      it "should discover '#{label}'" do
        format.should == RDF::RDFXML::Reader
      end
    end
  end

  context :interface do
    before(:each) do
      @sampledoc = <<-EOF;
<?xml version="1.0" ?>
<GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/one">
      <ex:name>Foo</ex:name>
    </rdf:Description>
  </rdf:RDF>
  <blablabla />
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/two">
      <ex:name>Bar</ex:name>
    </rdf:Description>
  </rdf:RDF>
</GenericXML>
EOF
    end
    
    it "should yield reader" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::RDFXML::Reader)
      RDF::RDFXML::Reader.new(@sampledoc) do |reader|
        inner.called(reader.class)
      end
    end
    
    it "should return reader" do
      RDF::RDFXML::Reader.new(@sampledoc).should be_a(RDF::RDFXML::Reader)
    end
    
    it "should yield statements" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::Statement).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_statement do |statement|
        inner.called(statement.class)
      end
    end
    
    it "should yield triples" do
      inner = mock("inner")
      inner.should_receive(:called).with(RDF::URI, RDF::URI, RDF::Literal).twice
      RDF::RDFXML::Reader.new(@sampledoc).each_triple do |subject, predicate, object|
        inner.called(subject.class, predicate.class, object.class)
      end
    end
  end
  
  context "simple parsing" do
    it "should recognise and create single triple for empty non-RDF root" do
      sampledoc = %(<?xml version="1.0" ?>
        <NotRDF />)
      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      graph.size.should == 1
      statement = graph.statements.first
      statement.subject.class.should == RDF::Node
      statement.predicate.should == RDF.type
      statement.object.should == RDF::XML.NotRDF
    end
  
    it "should parse on XML documents with multiple RDF nodes" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<GenericXML xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/">
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/one">
      <ex:name>Foo</ex:name>
    </rdf:Description>
  </rdf:RDF>
  <blablabla />
  <rdf:RDF>
    <rdf:Description rdf:about="http://example.org/two">
      <ex:name>Bar</ex:name>
    </rdf:Description>
  </rdf:RDF>
</GenericXML>
EOF
      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      objects = graph.statements.map {|s| s.object.value}.sort
      objects.should == ["Bar", "Foo"]
    end
  
    it "should be able to parse a simple single-triple document" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:ex="http://www.example.org/" xml:lang="en" xml:base="http://www.example.org/foo">
  <ex:Thing rdf:about="http://example.org/joe" ex:name="bar">
    <ex:belongsTo rdf:resource="http://tommorris.org/" />
    <ex:sampleText rdf:datatype="http://www.w3.org/2001/XMLSchema#string">foo</ex:sampleText>
    <ex:hadADodgyRelationshipWith>
      <rdf:Description>
        <ex:name>Tom</ex:name>
        <ex:hadADodgyRelationshipWith>
          <rdf:Description>
            <ex:name>Rob</ex:name>
            <ex:hadADodgyRelationshipWith>
              <rdf:Description>
                <ex:name>Mary</ex:name>
              </rdf:Description>
            </ex:hadADodgyRelationshipWith>
          </rdf:Description>
        </ex:hadADodgyRelationshipWith>
      </rdf:Description>
    </ex:hadADodgyRelationshipWith>
  </ex:Thing>
</rdf:RDF>
EOF

      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      #puts @debug
      graph.size.should == 10
      # print graph.dump(:ntriples
      # TODO: add datatype parsing
      # TODO: make sure the BNode forging is done correctly - an internal element->nodeID mapping
      # TODO: proper test
    end

    it "should be able to handle Bags/Alts etc." do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:eg="http://example.org/">
  <rdf:Bag>
    <rdf:li rdf:resource="http://tommorris.org/" />
    <rdf:li rdf:resource="http://twitter.com/tommorris" />
  </rdf:Bag>
</rdf:RDF>
EOF
      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      graph.predicates.map(&:to_s).should include("http://www.w3.org/1999/02/22-rdf-syntax-ns#_1", "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2")
    end
  end
  
  context :exceptions do
    it "should raise an error if rdf:aboutEach is used, as per the negative parser test rdfms-abouteach-error001 (rdf:aboutEach attribute)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">

  <rdf:Bag rdf:ID="node">
    <rdf:li rdf:resource="http://example.org/node2"/>
  </rdf:Bag>

  <rdf:Description rdf:aboutEach="#node">
    <dc:rights xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:rights>

  </rdf:Description>

</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEach/)
    end

    it "should raise an error if rdf:aboutEachPrefix is used, as per the negative parser test rdfms-abouteach-error002 (rdf:aboutEachPrefix attribute)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">

  <rdf:Description rdf:about="http://example.org/node">
    <eg:property>foo</eg:property>
  </rdf:Description>

  <rdf:Description rdf:aboutEachPrefix="http://example.org/">
    <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">me</dc:creator>

  </rdf:Description>

</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*aboutEachPrefix/)
    end

    it "should fail if given a non-ID as an ID (as per rdfcore-rdfms-rdf-id-error001)" do
      sampledoc = <<-EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:Description rdf:ID='333-555-666' />
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      end.should raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
    end

    it "should make sure that the value of rdf:ID attributes match the XML Name production (child-element version)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">
 <rdf:Description>
   <eg:prop rdf:ID="q:name" />
 </rdf:Description>
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      end.should raise_error(RDF::ReaderError, /ID addtribute '.*' must be a NCName/)
    end

    it "should make sure that the value of rdf:ID attributes match the XML Name production (data attribute version)" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:eg="http://example.org/">
 <rdf:Description rdf:ID="a/b" eg:prop="val" />
</rdf:RDF>
EOF
  
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      end.should raise_error(RDF::ReaderError, "ID addtribute 'a/b' must be a NCName")
    end
  
    it "should detect bad bagIDs" do
      sampledoc = <<-EOF;
<?xml version="1.0" ?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:Description rdf:bagID='333-555-666' />
</rdf:RDF>
EOF
    
      lambda do
        graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
        puts @debug
      end.should raise_error(RDF::ReaderError, /Obsolete attribute .*bagID/)
    end
  end
  
  context :reification do
    it "should be able to reify according to §2.17 of RDF/XML Syntax Specification" do
      sampledoc = <<-EOF;
<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/stuff/1.0/"
         xml:base="http://example.org/triples/">
  <rdf:Description rdf:about="http://example.org/">
    <ex:prop rdf:ID="triple1">blah</ex:prop>
  </rdf:Description>
</rdf:RDF>
EOF

      triples = <<-EOF
<http://example.org/> <http://example.org/stuff/1.0/prop> \"blah\" .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <http://example.org/> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <http://example.org/stuff/1.0/prop> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> \"blah\" .
EOF

      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      graph.should be_equivalent_graph(triples, :about => "http://example.com/", :trace => @debug)
    end
  end
  
  context :entities do
    it "decodes" do
      sampledoc = <<-EOF;
<?xml version="1.0"?>
<!DOCTYPE rdf:RDF [<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#" >]>
<rdf:RDF xmlns:rdf="&rdf;"
         xmlns:ex="http://example.org/stuff/1.0/"
         xml:base="http://example.org/triples/">
  <rdf:Description rdf:about="http://example.org/">
    <ex:prop rdf:ID="triple1">blah</ex:prop>
  </rdf:Description>
</rdf:RDF>
EOF

      triples = <<-EOF
<http://example.org/> <http://example.org/stuff/1.0/prop> \"blah\" .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <http://example.org/> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <http://example.org/stuff/1.0/prop> .
<http://example.org/triples/#triple1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> \"blah\" .
EOF

      graph = parse(sampledoc, :base_uri => "http://example.com", :validate => true)
      graph.should be_equivalent_graph(triples, :about => "http://example.com/", :trace => @debug)
    end

    it "processes OWL definition" do
      @debug = []
      graph = RDF::Graph.load("http://www.w3.org/2002/07/owl", :format => :rdfxml, :debug => @debug)
      graph.count.should > 10
    end
  end

  # W3C Test suite from http://www.w3.org/2000/10/rdf-tests/rdfcore/
  describe "w3c rdfcore tests" do
    require 'rdf_test'
    
    # Positive parser tests should raise errors.
    describe "positive parser tests" do
      Fixtures::TestCase::PositiveParserTest.each do |t|
        next unless t.status == "APPROVED"
        #next unless t.about =~ /rdfms-rdf-names-use/
        #next unless t.name =~ /11/
        #puts t.inspect
        specify "#{t.name}: " + (t.description || "#{t.inputDocument} against #{t.outputDocument}") do
          begin
            graph = RDF::Graph.new << RDF::RDFXML::Reader.new(t.input,
              :base_uri => t.inputDocument,
              :validate => false,
              :debug => t.debug)

            # Parse result graph
            #puts "parse #{self.outputDocument} as #{RDF::Reader.for(self.outputDocument)}"
            format = detect_format(t.output)
            output_graph = RDF::Graph.load(t.outputDocument, :format => format, :base_uri => t.inputDocument)
            puts "result: #{CGI.escapeHTML(graph.dump(:ntriples))}" if ::RDF::N3::debug?
            graph.should be_equivalent_graph(output_graph, t)
          rescue RSpec::Expectations::ExpectationNotMetError => e
            if t.inputDocument =~ %r(xml-literal|xml-canon)
              pending("XMLLiteral canonicalization not implemented yet")
            else
              raise
            end
          end
        end
      end
    end
    
    # Negative parser tests should raise errors.
    describe "negative parser tests" do
      Fixtures::TestCase::NegativeParserTest.each do |t|
        next unless t.status == "APPROVED"
        #next unless t.about =~ /rdfms-empty-property-elements/
        #next unless t.name =~ /1/
        #puts t.inspect
        specify "test #{t.name}: " + (t.description || t.inputDocument) do
          lambda do
            RDF::Graph.new << RDF::RDFXML::Reader.new(t.input,
              :base_uri => t.inputDocument,
              :validate => true)
          end.should raise_error(RDF::ReaderError)
        end
      end
    end
  end
  
  def parse(input, options)
    @debug = []
    graph = RDF::Graph.new
    RDF::RDFXML::Reader.new(input, options.merge(:debug => @debug)).each do |statement|
      graph << statement
    end
    graph
  end
end

