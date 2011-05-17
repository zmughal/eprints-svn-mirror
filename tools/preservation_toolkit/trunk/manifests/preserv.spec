package: preserv
version: 1.2.0
title: EPrints Preservation Toolkit
description: The Preserv Plugins for EPrints
configuration_file: Admin::PreservCheck
creator: Dave Tarrant <davetaz@ecs.soton.ac.uk>
icon: preservation_toolkit.png
=FILES=
cfg/cfg.d/pronom_internal.pl
cfg/cfg.d/pronom.pl
cfg/plugins/EPrints/Plugin/Event/Migration.pm
cfg/plugins/EPrints/Plugin/Event/Delete_Plan_Docs.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/FormatsRisks_delete_plan.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/FormatsRisks_download.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/FormatsRisks_get_plan.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/RepositoryClassify.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/FormatsRisks_enact_plan.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/PreservCheck.pm
cfg/plugins/EPrints/Plugin/Screen/Admin/FormatsRisks.pm
cfg/lang/en/phrases/preserv_extra.xml
cfg/lang/en/phrases/formats_risks.xml
cfg/citations/eprint/summary_page_preserv.xml
bin/update_pronom_puids_detached.pl
bin/update_pronom_puids
