package: preserv
title: EPrints Preservation Toolkit
description: The EPrints Preservation Toolkit is designed to combine with the DROID and Plato tools and add complete preservation workflow capability to an EPrints archive. Using DROID, the first stage is to classify all the files in the repository, providing a preserv profile. To any at risk file types a collection of files can be downloaded and supplied to the Plato tool in order to carry out preservation planning. Lastly any action that resulted from the preservation planning in Plato can be enacted automatically by the repository for all files of the same type.
configuration_file: Admin::PreservCheck
creator: Dave Tarrant <davetaz@ecs.soton.ac.uk>
category: toolkit
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
