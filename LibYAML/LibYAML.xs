#include <perl_libyaml.h>
/* XXX Make -Wall not complain about 'local_patches' not being used. */
#if !defined(PERL_PATCHLEVEL_H_IMPLICIT)
void xxx_local_patches_xs() { printf("%s", local_patches[0]); }
#endif

MODULE = YAML::XS::LibYAML		PACKAGE = YAML::XS::LibYAML		

PROTOTYPES: DISABLE

void
Load (yaml_sv)
        SV *yaml_sv
        PPCODE:
        PL_markstack_ptr++;
        Load(yaml_sv);
        return;

void
Dump (...)
        PPCODE:
        SV *dummy = NULL;
        PL_markstack_ptr++;
        Dump(dummy);
        return;

SV *
libyaml_version()
    CODE:
    {
        const char *v = yaml_get_version_string();
        RETVAL = newSVpv(v, strlen(v));

    }
    OUTPUT: RETVAL


MODULE = YAML::XS::LibYAML  PACKAGE = YAML::XS

PROTOTYPES: DISABLE

SV *
new(char *class_name, ...)
    PPCODE:
    {
        dXCPT;
        perl_yaml_xs_t *yaml;
        SV *point_sv;
        SV *point_svrv;
        SV *sv;
        HV *hash;
        SV *object;
        int i;
        int intvalue = 0;
        char *stringvalue;

        XCPT_TRY_START
        {
            yaml = (perl_yaml_xs_t*) malloc(sizeof(perl_yaml_xs_t));
            yaml->indent = 2;
            yaml->header = 1;
            yaml->footer = 0;
            yaml->width = 80;
            yaml->require_footer = 0;
            yaml->anchor_prefix = "";
            yaml->cyclic_refs = 0;
            yaml->utf8 = 0;
            yaml->boolean = 0;
            hash = newHV();

            if (items > 1) {
                for (i = 1; i < items; i+=2) {
                    if (i+1 >= items)
                        break;
                    if (SvPOK(ST(1))) {
                        char *key = (char *)SvPV_nolen(ST(i));
                        if (strEQ(key, "indent")) {
                            intvalue = SvIV(ST(i+1));
                            SV *indent_sv = newSViv(intvalue);
                            hv_store(hash, "indent", 6, indent_sv, 0);
                            yaml->indent = intvalue;
                        }
                        else if (strEQ(key, "utf8")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "utf8", 4, sv, 0);
                            yaml->utf8 = intvalue;
                        }
                        else if (strEQ(key, "header")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "header", 6, sv, 0);
                            yaml->header = intvalue;
                        }
                        else if (strEQ(key, "footer")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "footer", 6, sv, 0);
                            yaml->footer = intvalue;
                        }
                        else if (strEQ(key, "width")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "width", 5, sv, 0);
                            yaml->width = intvalue;
                        }
                        else if (strEQ(key, "require_footer")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "require_footer", 14, sv, 0);
                            yaml->require_footer = intvalue;
                        }
                        else if (strEQ(key, "anchor_prefix")) {
                            stringvalue = SvPV_nolen(ST(i+1));
                            SV *sv = newSVpvn(stringvalue, 0);
                            hv_store(hash, "anchor_prefix", 13, sv, 0);
                            yaml->anchor_prefix = stringvalue;
                        }
                        else if (strEQ(key, "cyclic_refs")) {
                            intvalue = SvIV(ST(i+1));
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "cyclic_refs", 11, sv, 0);
                            yaml->cyclic_refs = intvalue;
                        }
                        else if (strEQ(key, "boolean")) {
                            stringvalue = SvPV_nolen(ST(i+1));
                            intvalue = 0;
                            if (strEQ(stringvalue, "JSON::PP")) {
                                intvalue = BOOLEAN_JSON_PP;
                            }
                            else if (strEQ(stringvalue, "boolean")) {
                                intvalue = BOOLEAN_BOOLEAN;
                            }
                            else {
                                croak("%s",
                                    "YAML::XS->new: boolean only accepts 'JSON::PP', 'boolean' or a false value");
                            }
                            SV *sv = newSViv(intvalue);
                            hv_store(hash, "boolean", 7, sv, 0);
                            yaml->boolean = intvalue;
                        }
                    }
                }
            }

            point_sv = newSViv(PTR2IV(yaml));
            hv_store(hash, "ptr", 3, point_sv, 0);

            point_svrv = sv_2mortal(newRV_noinc((SV*)hash));
            object = sv_bless(point_svrv, gv_stashpv(class_name, 1));
        } XCPT_TRY_END

        XCPT_CATCH
        {
            XCPT_RETHROW;
        }
        XPUSHs(object);
        XSRETURN(1);
    }

void
load(SV *object, SV *string)
    PPCODE:
    {
        dXCPT;
        perl_yaml_xs_t *yaml;
        perl_oo_loader_t loader = {0};
        HV *hash;
        SV **val;
        STRLEN yaml_len;
        const unsigned char *yaml_str;
        const char *problem;

        hash = (HV*)(SvROK(object)? SvRV(object): object);
        val = hv_fetch(hash, "ptr", 3, TRUE);

        if (!val || !SvOK(*val) || !SvIOK(*val)) {
            PUTBACK;
            return;
        }

        yaml_str = (const unsigned char *)SvPV_const(string, yaml_len);
        yaml = INT2PTR(perl_yaml_xs_t*, SvIV(*val));

        yaml_parser_initialize(&loader.parser);
        yaml_parser_set_input_string(
            &loader.parser,
            yaml_str,
            yaml_len
        );
        PUSHMARK(sp);
        XCPT_TRY_START
        {
            oo_load_stream(yaml, &loader);
        } XCPT_TRY_END

        XCPT_CATCH
        {
            //fprintf(stderr, "=============== load EXCEPTION\n");
            yaml_event_delete(&loader.event);
            yaml_parser_delete(&loader.parser);
            //fprintf(stderr, "=============== load after yaml_parser_delete\n");
            XCPT_RETHROW;
        }
        yaml_parser_delete(&loader.parser);
        return;
    }

SV *
dump(SV *object, ...)
    PPCODE:
    {
        dXCPT;

        perl_yaml_xs_t *yaml;
        perl_oo_dumper_t dumper;
        HV *hash;
        SV **val;
        SV *string = newSVpvn("", 0);

        hash = (HV*)(SvROK(object)? SvRV(object): object);
        val = hv_fetch(hash, "ptr", 3, TRUE);

        if (!val || !SvOK(*val) || !SvIOK(*val)) {
            PUTBACK;
            return;
        }

        yaml = INT2PTR(perl_yaml_xs_t*, SvIV(*val));
        yaml_emitter_initialize(&dumper.emitter);
        yaml_emitter_set_unicode(&dumper.emitter, 1);
        yaml_emitter_set_indent(&dumper.emitter, yaml->indent);
        yaml_emitter_set_width(&dumper.emitter, yaml->width);
        yaml_emitter_set_output(&dumper.emitter, &append_output, (void *) string);

        PUSHMARK(sp);
        XCPT_TRY_START
        {
            oo_dump_stream(yaml, &dumper, items);
            if (string) {
                if (! yaml->utf8) {
                    SvUTF8_on(string);
                }
            }
        } XCPT_TRY_END

        XCPT_CATCH
        {
            yaml_emitter_delete(&dumper.emitter);
            XCPT_RETHROW;
        }

        yaml_emitter_delete(&dumper.emitter);
        XPUSHs(string);
        XSRETURN(1);
    }

void
DESTROY(SV *object)
    PPCODE:
    {
        dXCPT;
        perl_yaml_xs_t *yaml;
        HV *hash;
        SV **val;

        hash = (HV*)(SvROK(object)? SvRV(object): object);
        val = hv_fetch(hash, "ptr", 3, TRUE);
        //fprintf(stderr, "=============== DESTROY\n");
        if (val && SvOK(*val) && SvIOK(*val)) {
            yaml = INT2PTR(perl_yaml_xs_t*, SvIV(*val));
            free(yaml);
            yaml = NULL;
        }
        XSRETURN(0);
    }

