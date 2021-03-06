module Neo4j
  module Relationships

    class IllegalTraversalArguments < StandardError;
    end

    # Enables traversing nodes
    # Contains state about one specific traversal to be performed.
    class NodeTraverser
      include Enumerable

      attr_accessor :raw
      attr_reader :_java_node

      def initialize(_java_node, raw = false)
        @_java_node = _java_node
        @raw = raw
        @stop_evaluator = DepthStopEvaluator.new(1)
        @types_and_dirs = [] # what types of relationships and which directions should be traversed
        @traverser_order = org.neo4j.graphdb.Traverser::Order::BREADTH_FIRST
        @returnable_evaluator = org.neo4j.graphdb.ReturnableEvaluator::ALL_BUT_START_NODE
      end

      # if raw == true then it will return raw Java object instead of wrapped JRuby object which can improve performance.
      def raw(raw = true)
        @raw = raw
        self
      end

      # Sets the depth of the traversal.
      # Default is 1 if not specified.
      #
      # ==== Example
      #  morpheus.outgoing(:friends).depth(:all).each { ... }
      #  morpheus.outgoing(:friends).depth(3).each { ... }
      #
      # ==== Arguments
      # d<Fixnum,Symbol>:: the depth or :all if traversing to the end of the network.
      # ==== Return
      # self
      #
      # :api: public
      def depth(d)
        if d == :all
          @stop_evaluator = org.neo4j.graphdb.StopEvaluator::END_OF_GRAPH
        else
          @stop_evaluator = DepthStopEvaluator.new(d)
        end
        self
      end

      def filter(&proc)
        @returnable_evaluator = ReturnableEvaluator.new(proc, @raw)
        self
      end

      def outgoing(*types)
        types.each do |type|
          @types_and_dirs << org.neo4j.graphdb.DynamicRelationshipType.withName(type.to_s)
          @types_and_dirs << org.neo4j.graphdb.Direction::OUTGOING
        end
        self
      end

      def incoming(*types)
        types.each do |type|
          @types_and_dirs << org.neo4j.graphdb.DynamicRelationshipType.withName(type.to_s)
          @types_and_dirs << org.neo4j.graphdb.Direction::INCOMING
        end
        self
      end

      def both(*types)
        types.each do |type|
          @types_and_dirs << org.neo4j.graphdb.DynamicRelationshipType.withName(type.to_s)
          @types_and_dirs << org.neo4j.graphdb.Direction::BOTH
        end
        self
      end

      def empty?
        !iterator.hasNext
      end

      def first
        find {true}
      end

      def each
        iter = iterator
        if @raw
          while (iter.hasNext) do
            yield iter.next
          end
        else
          while (iter.hasNext) do
            yield iter.next.wrapper
          end
        end
      end

      # Same as #each method but includes the TraversalPosition argument as a yield argument.
      #
      #
      def each_with_position(&block)
        traverser = create_traverser
        iter = traverser.iterator
        while (iter.hasNext) do
          n = iter.next
          tp = TraversalPosition.new(traverser.currentPosition(), @raw)
          block.call Neo4j.load_node(n.get_id), tp
        end
      end


      def create_traverser
        # check that we know which type of relationship should be traversed
        if @types_and_dirs.empty?
          raise IllegalTraversalArguments.new "Unknown type of relationship. Needs to know which type(s) of relationship in order to traverse. Please use the outgoing, incoming or both method."
        end

        @_java_node.traverse(@traverser_order, @stop_evaluator,
                                @returnable_evaluator, @types_and_dirs.to_java(:object))
      end

      def iterator
        create_traverser.iterator
      end

      def to_s
        "NodeTraverser [direction=#{@direction}, type=#{@type}]"
      end

    end


  end
end
