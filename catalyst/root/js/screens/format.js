Paperpile.Format = Ext.extend(Ext.Panel, {

    title: 'Format',
    iconCls: 'pp-icon-statistics',

    markup: ['<div id="container">', '<p>INHERE</p>', '</div>'],

    initComponent: function() {
        Ext.apply(this, {
            closable: true,
        });

        Paperpile.PatternSettings.superclass.initComponent.call(this);

        this.tpl = new Ext.XTemplate(this.markup);

    },

    afterRender: function() {
        Paperpile.Format.superclass.afterRender.apply(this, arguments);

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/misc/preprocess_csl'),
            params: {
                selection: this.selection,
                grid_id: this.grid_id,
            },
            method: 'GET',
            success: function(response) {
                var json = Ext.util.JSON.decode(response.responseText);

                //sys.loadData(json.data);
                sys.loadData([{
                    "id": "ITEM-1",
                    "type": "article-journal",
                    "container-title": "Nature",
                    "volume": "10",
                    "issue": "5",
                    "page": "100-123",
                    "author": [{
                        "name": "Doe, John",
                        "primary-key": "Doe",
                        "secondary-key": "John"
                    }],
                    "title": "My important paper",
                    "issued": {
                        "year": "2006"
                    }
                },

                {
                    "id": "ITEM-2",
                    "type": "book",
                    "author": [{
                        "name": " Roe, Jane",
                        "primary-key": "Roe",
                        "secondary-key": "Jane"
                    }],
                    "title": "Book B: quiet reflections on anonymity",
                    "issued": {
                        "year": "2007"
                    }
                }]);

                //console.log(sys);
                locales = new Object();
                locales["en"] = "<terms xmlns=\"http://purl.org/net/xbiblio/csl\">\n  <locale xml:lang=\"en\">\n    <term name=\"at\">at</term>\n    <term name=\"in\">in</term>\n    <term name=\"ibid\">ibid</term>\n    <term name=\"accessed\">accessed</term>\n    <term name=\"retrieved\">retrieved</term>\n    <term name=\"from\">from</term>\n    <term name=\"forthcoming\">forthcoming</term>\n    <term name=\"reference\">\n      <single>reference</single>\n      <multiple>references</multiple>\n    </term>\n    <term name=\"no date\">n.d.</term>\n    <term name=\"and\">and</term>\n    <term name=\"et-al\">et al.</term>\n    <term name=\"interview\">interview</term>\n    <term name=\"letter\">letter</term>\n    <term name=\"anonymous\">anonymous</term>\n    <term name=\"anonymous\" form=\"short\">anon</term>\n    <term name=\"and others\">and others</term>\n    <term name=\"in press\">in press</term>\n    <term name=\"online\">online</term>\n    <term name=\"cited\">cited</term>\n    <term name=\"internet\">internet</term>\n    <term name=\"presented at\">presented at the</term>\n    <term name=\"filed\">filed</term>\n    <term name=\"slip opinion\">slip op.</term>\n\t<term name=\"revised\">rev'd</term>\n\n    <!-- CATEGORIES -->\n    <term name=\"anthropology\">anthropology</term>\n    <term name=\"astronomy\">astronomy</term>\n    <term name=\"biology\">biology</term>\n    <term name=\"botany\">botany</term>\n    <term name=\"chemistry\">chemistry</term>\n    <term name=\"engineering\">engineering</term>\n    <term name=\"generic-base\">generic base</term>\n    <term name=\"geography\">geography</term>\n    <term name=\"geology\">geology</term>\n    <term name=\"history\">history</term>\n    <term name=\"humanities\">humanities</term>\n    <term name=\"literature\">literature</term>\n    <term name=\"math\">math</term>\n    <term name=\"medicine\">medicine</term>\n    <term name=\"philosophy\">philosophy</term>\n    <term name=\"physics\">physics</term>\n    <term name=\"psychology\">psychology</term>\n    <term name=\"sociology\">sociology</term>\n    <term name=\"science\">science</term>\n    <term name=\"political_science\">political science</term>\n    <term name=\"social_science\">social science</term>\n    <term name=\"theology\">theology</term>\n    <term name=\"zoology\">zoology</term>\n    \n    <!-- LONG LOCATOR FORMS -->\n    <term name=\"book\">\n      <single>book</single>\n      <multiple>books</multiple>\n    </term>\n    <term name=\"chapter\">\n      <single>chapter</single>\n      <multiple>chapters</multiple>\n    </term>\n    <term name=\"column\">\n      <single>column</single>\n      <multiple>columns</multiple>\n    </term>\n    <term name=\"figure\">\n      <single>figure</single>\n      <multiple>figures</multiple>\n    </term>\n    <term name=\"folio\">\n      <single>folio</single>\n      <multiple>folios</multiple>\n    </term>\n    <term name=\"issue\">\n      <single>number</single>\n      <multiple>numbers</multiple>\n    </term>\n    <term name=\"line\">\n      <single>line</single>\n      <multiple>lines</multiple>\n    </term>\n    <term name=\"note\">\n      <single>note</single>\n      <multiple>notes</multiple>\n    </term>\n    <term name=\"opus\">\n      <single>opus</single>\n      <multiple>opera</multiple>\n    </term>\n    <term name=\"page\">\n      <single>page</single>\n      <multiple>pages</multiple>\n    </term>\n    <term name=\"paragraph\">\n      <single>paragraph</single>\n      <multiple>paragraph</multiple>\n    </term>\n    <term name=\"part\">\n      <single>part</single>\n      <multiple>parts</multiple>\n    </term>\n    <term name=\"section\">\n      <single>section</single>\n      <multiple>sections</multiple>\n    </term>\n    <term name=\"volume\">\n      <single>volume</single>\n      <multiple>volumes</multiple>\n    </term>\n    <term name=\"edition\">\n      <single>edition</single>\n      <multiple>editions</multiple>\n    </term>\n    <term name=\"verse\">\n      <single>verse</single>\n      <multiple>verses</multiple>\n    </term>\n    <term name=\"sub verbo\">\n      <single>sub verbo</single>\n      <multiple>s.vv</multiple>\n    </term>\n    \n    <!-- SHORT LOCATOR FORMS -->\n    <term name=\"book\" form=\"short\">bk</term>\n    <term name=\"chapter\" form=\"short\">chap</term>\n    <term name=\"column\" form=\"short\">col</term>\n    <term name=\"figure\" form=\"short\">fig</term>\n    <term name=\"folio\" form=\"short\">f</term>\n    <term name=\"issue\" form=\"short\">no</term>\n    <term name=\"opus\" form=\"short\">op</term>\n    <term name=\"page\" form=\"short\">\n      <single>p</single>\n      <multiple>pp</multiple>\n    </term>\n    <term name=\"paragraph\" form=\"short\">para</term>\n    <term name=\"part\" form=\"short\">pt</term>\n    <term name=\"section\" form=\"short\">sec</term>\n    <term name=\"sub verbo\" form=\"short\">\n      <single>s.v</single>\n      <multiple>s.vv</multiple>\n    </term>\n    <term name=\"verse\" form=\"short\">\n      <single>v</single>\n      <multiple>vv</multiple>\n    </term>\n    <term name=\"volume\" form=\"short\">\n    \t<single>vol</single>\n    \t<multiple>vols</multiple>\n    </term>\n    <term name=\"edition\">edition</term>\n    <term name=\"edition\" form=\"short\">ed</term>\n    \n    <!-- SYMBOL LOCATOR FORMS -->\n    <term name=\"paragraph\" form=\"symbol\">\n      <single>\u00b6</single>\n      <multiple>\u00b6\u00b6</multiple>\n    </term>\n    <term name=\"section\" form=\"symbol\">\n      <single>\u00a7</single>\n      <multiple>\u00a7\u00a7</multiple>\n    </term>\n    \n    <!-- LONG ROLE FORMS -->\n    <term name=\"author\">\n      <single></single>\n      <multiple></multiple>\n    </term>\n    <term name=\"editor\">\n      <single>editor</single>\n      <multiple>editors</multiple>\n    </term>\n    <term name=\"translator\">\n      <single>translator</single>\n      <multiple>translators</multiple>\n    </term>\n    \n    <!-- SHORT ROLE FORMS -->\n    <term name=\"author\" form=\"short\">\n      <single></single>\n      <multiple></multiple>\n    </term>\n    <term name=\"editor\" form=\"short\">\n      <single>ed</single>\n      <multiple>eds</multiple>\n    </term>\n    <term name=\"translator\" form=\"short\">\n      <single>tran</single>\n      <multiple>trans</multiple>\n    </term>\n    \n    <!-- VERB ROLE FORMS -->\n    <term name=\"editor\" form=\"verb\">edited by</term>\n    <term name=\"translator\" form=\"verb\">translated by</term>\n    <term name=\"recipient\" form=\"verb\">to</term>\n    <term name=\"interviewer\" form=\"verb\">interview by</term>\n    \n    <!-- SHORT VERB ROLE FORMS -->\n    <term name=\"editor\" form=\"verb-short\">ed</term>\n    <term name=\"translator\" form=\"verb-short\">trans</term>\n    \n    <!-- LONG MONTH FORMS -->\n    <term name=\"month-01\">January</term>\n    <term name=\"month-02\">February</term>\n    <term name=\"month-03\">March</term>\n    <term name=\"month-04\">April</term>\n    <term name=\"month-05\">May</term>\n    <term name=\"month-06\">June</term>\n    <term name=\"month-07\">July</term>\n    <term name=\"month-08\">August</term>\n    <term name=\"month-09\">September</term>\n    <term name=\"month-10\">October</term>\n    <term name=\"month-11\">November</term>\n    <term name=\"month-12\">December</term>\n    \n    <!-- SHORT MONTH FORMS -->\n    <term name=\"month-01\" form=\"short\">Jan</term>\n    <term name=\"month-02\" form=\"short\">Feb</term>\n    <term name=\"month-03\" form=\"short\">Mar</term>\n    <term name=\"month-04\" form=\"short\">Apr</term>\n\t<term name=\"month-05\" form=\"short\">May</term>\n    <term name=\"month-06\" form=\"short\">Jun</term>\n    <term name=\"month-07\" form=\"short\">Jul</term>\n    <term name=\"month-08\" form=\"short\">Aug</term>\n    <term name=\"month-09\" form=\"short\">Sep</term>\n    <term name=\"month-10\" form=\"short\">Oct</term>\n    <term name=\"month-11\" form=\"short\">Nov</term>\n    <term name=\"month-12\" form=\"short\">Dec</term>\n  </locale>\n</terms>\n";

                var style = CSL.makeStyle(sys, "<style xmlns=\"http://purl.org/net/xbiblio/csl\" xml:lang=\"en\" class=\"in-text\" >  <info>    <title>Chicago Manual of Style (Author-Date format)</title>    <id>http://www.zotero.org/styles/chicago-author-date</id>    <link href=\"http://www.zotero.org/styles/chicago-author-date\"/>    <author>      <name>Julian Onions</name>      <email>julian.onions@gmail.com</email>    </author>    <category term=\"author-date\"/>    <category term=\"generic-base\"/>    <updated/>    <summary>The author-date variant of the Chicago style</summary>    <link href=\"http://www.chicagomanualofstyle.org/tools_citationguide.html\" rel=\"documentation\"/>  </info>  <macro name=\"secondary-contributors\">    <choose>      <if type=\"chapter\" match=\"none\">    <group delimiter=\". \">      <choose>        <if variable=\"author\">      <names variable=\"editor\">        <label form=\"verb-short\" prefix=\" \" text-case=\"capitalize-first\" suffix=\". \"/>        <name and=\"text\" delimiter=\", \"/>      </names>        </if>      </choose>      <choose>        <if variable=\"author editor\" match=\"any\">          <names variable=\"translator\">            <label form=\"verb-short\" prefix=\" \" text-case=\"capitalize-first\" suffix=\". \"/>            <name and=\"text\" delimiter=\", \"/>          </names>        </if>      </choose>    </group>      </if>    </choose>  </macro>  <macro name=\"container-contributors\">    <choose>      <if type=\"chapter\">    <group prefix=\",\" delimiter=\", \">      <choose>        <if variable=\"author\">      <names variable=\"editor\">        <label form=\"verb-short\" prefix=\" \" text-case=\"lowercase\" suffix=\". \"/>        <name and=\"text\" delimiter=\", \"/>      </names>        </if>      </choose>      <choose>        <if variable=\"author editor\" match=\"any\">          <names variable=\"translator\">            <label form=\"verb-short\" prefix=\" \" text-case=\"lowercase\" suffix=\". \"/>            <name and=\"text\" delimiter=\", \"/>          </names>        </if>      </choose>    </group>      </if>    </choose>  </macro>  <macro name=\"anon\">    <choose>      <if variable=\"author editor translator\" match=\"none\">    <text term=\"anonymous\" form=\"short\" text-case=\"capitalize-first\"/>	  </if>	</choose>  </macro>  <macro name=\"editor\">    <names variable=\"editor\">      <name name-as-sort-order=\"first\" and=\"text\" sort-separator=\", \" delimiter=\", \" delimiter-precedes-last=\"always\"/>      <label form=\"short\" prefix=\", \" suffix=\".\"/>    </names>  </macro>  <macro name=\"translator\">    <names variable=\"translator\">      <name name-as-sort-order=\"first\" and=\"text\" sort-separator=\", \" delimiter=\", \" delimiter-precedes-last=\"always\"/>      <label form=\"verb-short\" prefix=\", \" suffix=\".\"/>    </names>  </macro>  <macro name=\"recipient\">    <choose>      <if type=\"personal_communication\">    	<choose>	  	  <if variable=\"genre\">		<text variable=\"genre\" text-case=\"capitalize-first\"/>	  	  </if>	  	  <else>		<text term=\"letter\" text-case=\"capitalize-first\"/>		  </else>	    </choose>	  </if>	</choose>    <names variable=\"recipient\" delimiter=\", \">      <label form=\"verb\" prefix=\" \" text-case=\"lowercase\" suffix=\" \"/>      <name and=\"text\" delimiter=\", \"/>    </names>  </macro>  <macro name=\"contributors\">    <names variable=\"author\">      <name and=\"text\" name-as-sort-order=\"first\" sort-separator=\", \" delimiter=\", \"        delimiter-precedes-last=\"always\"/>      <label form=\"verb-short\" prefix=\", \" suffix=\".\" text-case=\"lowercase\"/>      <substitute>        <text macro=\"editor\"/>        <text macro=\"translator\"/>      </substitute>    </names>    <text macro=\"anon\"/>    <text macro=\"recipient\"/>  </macro>  <macro name=\"contributors-short\">    <names variable=\"author\">      <name form=\"short\" and=\"text\" delimiter=\", \"/>      <substitute>        <names variable=\"editor\"/>        <names variable=\"translator\"/>      </substitute>    </names>    <text macro=\"anon\"/>  </macro>  <macro name=\"interviewer\">    <names variable=\"interviewer\" delimiter=\", \">      <label form=\"verb\" prefix=\" \" text-case=\"capitalize-first\" suffix=\" \"/>      <name and=\"text\" delimiter=\", \"/>    </names>  </macro>  <macro name=\"archive\">    <group delimiter=\". \">      <text variable=\"archive_location\" text-case=\"capitalize-first\"/>      <text variable=\"archive\"/>      <text variable=\"archive-place\"/>    </group>  </macro>  <macro name=\"access\">    <group delimiter=\". \">	  <choose>	    <if type=\"graphic report\" match=\"any\">      <text macro=\"archive\"/>	    </if>	    <else-if type=\"book thesis chapter article-journal article-newspaper article-magazine\" match=\"none\">      <text macro=\"archive\"/>	    </else-if>	  </choose>      <text variable=\"DOI\" prefix=\"doi:\"/>      <text variable=\"URL\"/>    </group>  </macro>  <macro name=\"title\">    <choose>      <if variable=\"title\" match=\"none\">        <choose>          <if type=\"personal_communication\" match=\"none\">        <text variable=\"genre\" text-case=\"capitalize-first\"/>          </if>        </choose>      </if>      <else-if type=\"book\">        <text variable=\"title\" font-style=\"italic\"/>      </else-if>      <else>        <text variable=\"title\"/>      </else>    </choose>  </macro>  <macro name=\"edition\">    <choose>      <if type=\"book chapter\" match=\"any\">    <choose>      <if is-numeric=\"edition\">        <group delimiter=\" \">          <number variable=\"edition\" form=\"ordinal\"/>          <text term=\"edition\" form=\"short\" suffix=\".\"/>        </group>      </if>      <else>        <text variable=\"edition\" suffix=\".\"/>      </else>    </choose>      </if>    </choose>  </macro>  <macro name=\"locators\">    <choose>      <if type=\"article-journal\">        <text variable=\"volume\" prefix=\" \"/>        <text variable=\"issue\" prefix=\", no. \"/>      </if>      <else-if type=\"book\">        <group prefix=\". \" delimiter=\". \">          <group>            <text term=\"volume\" form=\"short\" text-case=\"capitalize-first\" suffix=\". \"/>            <number variable=\"volume\" form=\"numeric\"/>          </group>          <group>            <number variable=\"number-of-volumes\" form=\"numeric\"/>            <text term=\"volume\" form=\"short\" prefix=\" \" suffix=\".\" plural=\"true\"/>          </group>        </group>      </else-if>    </choose>  </macro>  <macro name=\"locators-chapter\">    <choose>      <if type=\"chapter\">        <group prefix=\", \">          <text variable=\"volume\" suffix=\":\"/>          <text variable=\"page\"/>        </group>      </if>    </choose>  </macro>  <macro name=\"locators-article\">    <choose>      <if type=\"article-newspaper\">        <group prefix=\", \" delimiter=\", \">          <group>        <text variable=\"edition\" suffix=\" \"/>        <text term=\"edition\" prefix=\" \"/>          </group>          <group>        <text term=\"section\" form=\"short\" suffix=\". \"/>        <text variable=\"section\"/>          </group>        </group>      </if>      <else-if type=\"article-journal\">    <text variable=\"page\" prefix=\": \"/>      </else-if>    </choose>  </macro>  <macro name=\"point-locators\">    <group>      <choose>	    <if locator=\"page\" match=\"none\">	  <label variable=\"locator\" form=\"short\" include-period=\"true\" suffix=\" \"/>	    </if>	  </choose>      <text variable=\"locator\"/>	</group>  </macro>  <macro name=\"container-prefix\">    <text term=\"in\" text-case=\"capitalize-first\"/>  </macro>  <macro name=\"container-title\">    <choose>      <if type=\"chapter\">        <text macro=\"container-prefix\" suffix=\" \"/>      </if>    </choose>    <text variable=\"container-title\" font-style=\"italic\"/>  </macro>  <macro name=\"publisher\">    <group delimiter=\": \">      <text variable=\"publisher-place\"/>      <text variable=\"publisher\"/>    </group>  </macro>  <macro name=\"date\">    <date variable=\"issued\">      <date-part name=\"year\"/>    </date>  </macro>  <macro name=\"day-month\">    <date variable=\"issued\">      <date-part name=\"month\"/>      <date-part name=\"day\" prefix=\" \"/>    </date>  </macro>  <macro name=\"collection-title\">    <text variable=\"collection-title\"/>    <text variable=\"collection-number\" prefix=\" \"/>  </macro>  <macro name=\"event\">    <group>      <text term=\"presented at\" suffix=\" \"/>      <text variable=\"event\"/>    </group>  </macro>  <macro name=\"description\">    <group delimiter=\". \">      <text macro=\"interviewer\"/>      <text variable=\"medium\" text-case=\"capitalize-first\"/>    </group>    <choose>      <if variable=\"title\" match=\"none\"> </if>      <else-if type=\"thesis\"> </else-if>      <else>        <text variable=\"genre\" text-case=\"capitalize-first\" prefix=\". \"/>      </else>    </choose>  </macro>  <macro name=\"issue\">    <choose>      <if type=\"article-journal\">        <text macro=\"day-month\" prefix=\" (\" suffix=\")\"/>      </if>      <else-if type=\"speech\">        <group prefix=\" \" delimiter=\", \">          <text macro=\"event\"/>          <text macro=\"day-month\"/>          <text variable=\"event-place\"/>        </group>      </else-if>      <else-if type=\"article-newspaper article-magazine\" match=\"any\">        <text macro=\"day-month\" prefix=\", \"/>      </else-if>      <else>        <group prefix=\". \" delimiter=\", \">          <choose>            <if type=\"thesis\">              <text variable=\"genre\" text-case=\"capitalize-first\"/>            </if>          </choose>          <text macro=\"publisher\"/>          <text macro=\"day-month\"/>        </group>      </else>    </choose>  </macro>  <citation>    <option name=\"et-al-min\" value=\"4\"/>    <option name=\"et-al-use-first\" value=\"1\"/>    <option name=\"et-al-subsequent-min\" value=\"4\"/>    <option name=\"et-al-subsequent-use-first\" value=\"1\"/>    <option name=\"disambiguate-add-year-suffix\" value=\"true\"/>    <option name=\"disambiguate-add-names\" value=\"true\"/>    <option name=\"disambiguate-add-givenname\" value=\"true\"/>    <layout prefix=\"(\" suffix=\")\" delimiter=\"; \">      <group delimiter=\", \">        <group delimiter=\" \">          <text macro=\"contributors-short\"/>          <text macro=\"date\"/>        </group>        <text macro=\"point-locators\"/>      </group>    </layout>  </citation>  <bibliography>    <option name=\"hanging-indent\" value=\"true\"/>    <option name=\"et-al-min\" value=\"11\"/>    <option name=\"et-al-use-first\" value=\"7\"/>    <option name=\"subsequent-author-substitute\" value=\"---\"/>    <option name=\"entry-spacing\" value=\"0\"/>    <sort>      <key macro=\"contributors\"/>      <key variable=\"issued\"/>    </sort>    <layout suffix=\".\">      <text macro=\"contributors\" suffix=\". \"/>      <text macro=\"date\" suffix=\". \"/>      <text macro=\"title\"/>      <text macro=\"description\"/>      <text macro=\"secondary-contributors\" prefix=\". \"/>      <text macro=\"container-title\" prefix=\". \"/>      <text macro=\"container-contributors\"/>      <text macro=\"locators-chapter\"/>      <text macro=\"edition\" prefix=\". \"/>      <text macro=\"locators\"/>      <text macro=\"collection-title\" prefix=\". \"/>      <text macro=\"issue\"/>      <text macro=\"locators-article\"/>      <text macro=\"access\" prefix=\". \"/>    </layout>  </bibliography></style>\n");

                /*
                var ids=[];

                for (var i=0; i< json.data.length;i++){
                    ids.push(json.data[i].id);
                }

                console.log(ids);
*/

                //style.insertItems(ids);
                //var result=style.makeBibliography();
            },
            scope: this
        });

        this.tpl.overwrite(this.body, {
            id: this.id
        },
        true);

    }
});