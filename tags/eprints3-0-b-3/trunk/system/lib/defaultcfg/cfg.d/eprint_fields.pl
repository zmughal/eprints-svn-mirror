
$c->{fields}->{eprint} = [

          {
            'name' => 'creators',
            'type' => 'compound',
            'multiple' => 1,
            'fields' => [
                          {
                            'sub_name' => 'name',
                            'type' => 'name',
                            'hide_honourific' => 1,
                            'hide_lineage' => 1,
                            'family_first' => 1,
                          },
                          {
                            'sub_name' => 'id',
                            'type' => 'text',
                            'input_cols' => 20,
                            'allow_null' => 1,
                          }
                        ],
            'input_boxes' => 4,
          },

          {
            'name' => 'corp_creators',
            'type' => 'text',
            'multiple' => 1,
          },

          {
            'name' => 'title',
            'type' => 'longtext',
            'input_rows' => 3,
          },

          {
            'name' => 'ispublished',
            'type' => 'set',
            'options' => [
                           'pub',
                           'inpress',
                           'submitted',
                           'unpub',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'subjects',
            'type' => 'subject',
            'multiple' => 1,
            'top' => 'subjects',
            'render_input' => 'EPrints::Extras::subject_browser_input',
            'browse_link' => 'subjects',
          },

          {
            'name' => 'full_text_status',
            'type' => 'set',
            'options' => [
                           'public',
                           'restricted',
                           'none',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'monograph_type',
            'type' => 'set',
            'options' => [
                           'technical_report',
                           'project_report',
                           'documentation',
                           'manual',
                           'working_paper',
                           'discussion_paper',
                           'other',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'pres_type',
            'type' => 'set',
            'options' => [
                           'paper',
                           'lecture',
                           'speech',
                           'poster',
                           'keynote',
                           'other',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'keywords',
            'type' => 'longtext',
            'input_rows' => 2,
          },

          {
            'name' => 'note',
            'type' => 'longtext',
            'input_rows' => 3,
          },

          {
            'name' => 'suggestions',
            'type' => 'longtext',
            'render_value' => 'EPrints::Extras::render_highlighted_field',
          },

          {
            'name' => 'abstract',
            'type' => 'longtext',
            'input_rows' => 10,
          },

          {
            'name' => 'date',
            'type' => 'date',
            'min_resolution' => 'year',
          },

          {
            'name' => 'date_type',
            'type' => 'set',
            'options' => [
                           'published',
                           'submitted',
                           'completed',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'series',
            'type' => 'text',
          },

          {
            'name' => 'publication',
            'type' => 'text',
          },

          {
            'name' => 'volume',
            'type' => 'text',
            'maxlength' => 6,
          },

          {
            'name' => 'number',
            'type' => 'text',
            'maxlength' => 6,
          },

          {
            'name' => 'publisher',
            'type' => 'text',
          },

          {
            'name' => 'place_of_pub',
            'type' => 'text',
          },

          {
            'name' => 'pagerange',
            'type' => 'pagerange',
          },

          {
            'name' => 'pages',
            'type' => 'int',
            'maxlength' => 6,
            'sql_index' => 0,
          },

          {
            'name' => 'event_title',
            'type' => 'text',
          },

          {
            'name' => 'event_location',
            'type' => 'text',
          },

          {
            'name' => 'event_dates',
            'type' => 'text',
          },

          {
            'name' => 'event_type',
            'type' => 'set',
            'options' => [
                           'conference',
                           'workshop',
                           'other',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'id_number',
            'type' => 'text',
          },

          {
            'name' => 'patent_applicant',
            'type' => 'text',
          },

          {
            'name' => 'institution',
            'type' => 'text',
          },

          {
            'name' => 'department',
            'type' => 'text',
          },

          {
            'name' => 'thesis_type',
            'type' => 'set',
            'options' => [
                           'masters',
                           'phd',
                           'engd',
                           'other',
                         ],
            'input_style' => 'medium',
          },

          {
            'name' => 'refereed',
            'type' => 'boolean',
            'input_style' => 'radio',
          },

          {
            'name' => 'isbn',
            'type' => 'text',
          },

          {
            'name' => 'issn',
            'type' => 'text',
          },

          {
            'name' => 'book_title',
            'type' => 'text',
          },

          {
            'name' => 'editors',
            'type' => 'compound',
            'multiple' => 1,
            'fields' => [
                          {
                            'hide_honourific' => 1,
                            'type' => 'name',
                            'hide_lineage' => 1,
                            'family_first' => 1,
                            'sub_name' => 'name',
                          },
                          {
                            'input_cols' => 20,
                            'allow_null' => 1,
                            'type' => 'text',
                            'sub_name' => 'id',
                          }
                        ],
            'input_boxes' => 4,
          },

          {
            'name' => 'official_url',
            'type' => 'url',
          },

          {
            'name' => 'related_url',
            'type' => 'compound',
            'multiple' => 1,
            'fields' => [
                          {
                            'sub_name' => 'url',
                            'type' => 'url',
                            'input_cols' => 40,
                          },
                          {
                            'sub_name' => 'type',
                            'type' => 'set',
                            'options' => [
                                           'pub',
                                           'author',
                                           'org',
                                         ],
                          }
                        ],
            'input_boxes' => 1,
            'input_ordered' => 0,
          },

          {
            'name' => 'referencetext',
            'type' => 'longtext',
            'input_rows' => 15,
          }

];