use Test::Pod::Coverage tests=>1;

pod_coverage_ok( "POE::Loop::Glib", {
		coverage_class => 'Pod::Coverage::CountParents',
	});

