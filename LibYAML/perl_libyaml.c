#include <perl_libyaml.h>

static SV *
call_coderef(SV *code, AV *args)
{
    dSP;
    SV **svp;
    I32 count = (args && args != Nullav) ? av_len(args) : -1;
    I32 i;

    PUSHMARK(SP);
    for (i = 0; i <= count; i++) {
        if ((svp = av_fetch(args, i, FALSE))) {
            XPUSHs(*svp);
        }
    }
    PUTBACK;
    count = call_sv(code, G_ARRAY);
    SPAGAIN;

    return fold_results(count);
}

static SV *
fold_results(I32 count)
{
    dSP;
    SV *retval = &PL_sv_undef;

    if (count > 1) {
        /* convert multiple return items into a list reference */
        AV *av = newAV();
        SV *last_sv = &PL_sv_undef;
        SV *sv = &PL_sv_undef;
        I32 i;

        av_extend(av, count - 1);
        for(i = 1; i <= count; i++) {
            last_sv = sv;
            sv = POPs;
            if (SvOK(sv) && !av_store(av, count - i, SvREFCNT_inc(sv)))
                SvREFCNT_dec(sv);
        }
        PUTBACK;

        retval = sv_2mortal((SV *) newRV_noinc((SV *) av));

        if (!SvOK(sv) || sv == &PL_sv_undef) {
            /* if first element was undef, die */
            croak("%sCall error", ERRMSG);
        }
        return retval;

    }
    else {
        if (count)
            retval = POPs;
        PUTBACK;
        return retval;
    }
}

static SV *
find_coderef(char *perl_var)
{
    SV *coderef;

    if ((coderef = get_sv(perl_var, FALSE))
        && SvROK(coderef)
        && SvTYPE(SvRV(coderef)) == SVt_PVCV)
        return coderef;

    return NULL;
}

/*
 * Piece together a parser/loader error message
 */
char *
loader_error_msg(perl_yaml_loader_t *loader, char *problem)
{
    char *msg;
    if (!problem)
        problem = (char *)loader->parser.problem;
    msg = form(
        LOADERRMSG
        "%swas found at "
        "document: %d",
        (problem ? form("The problem:\n\n    %s\n\n", problem) : "A problem "),
        loader->document
    );
    if (
        loader->parser.problem_mark.line ||
        loader->parser.problem_mark.column
    )
        msg = form("%s, line: %lu, column: %lu\n",
            msg,
            (unsigned long)loader->parser.problem_mark.line + 1,
            (unsigned long)loader->parser.problem_mark.column + 1
        );
    else
        msg = form("%s\n", msg);
    if (loader->parser.context)
        msg = form("%s%s at line: %lu, column: %lu\n",
            msg,
            loader->parser.context,
            (unsigned long)loader->parser.context_mark.line + 1,
            (unsigned long)loader->parser.context_mark.column + 1
        );

    return msg;
}

/*
 * This is the main Load function.
 * It takes a yaml stream and turns it into 0 or more Perl objects.
 */
void
Load(SV *yaml_sv)
{
    dXCPT;

    dXSARGS;
    perl_yaml_loader_t loader;
    SV *node;
    const unsigned char *yaml_str;
    STRLEN yaml_len;

    GV *gv = gv_fetchpv("YAML::XS::Boolean", FALSE, SVt_PV);
    char* boolean = "";
    loader.load_bool_jsonpp = 0;
    loader.load_bool_boolean = 0;
    if (SvTRUE(GvSV(gv))) {
        boolean = SvPV_nolen(GvSV(gv));
        if (strEQ(boolean, "JSON::PP")) {
            loader.load_bool_jsonpp = 1;
            load_module(PERL_LOADMOD_NOIMPORT, newSVpv("JSON::PP", 0), Nullsv);
        }
        else if (strEQ(boolean, "boolean")) {
            loader.load_bool_boolean = 1;
            load_module(PERL_LOADMOD_NOIMPORT, newSVpv("boolean", 0), Nullsv);
        }
        else {
            croak("%s",
                "$YAML::XS::Boolean only accepts 'JSON::PP', 'boolean' or a false value");
        }
    }

    loader.load_code = (
        ((gv = gv_fetchpv("YAML::XS::UseCode", TRUE, SVt_PV)) &&
        SvTRUE(GvSV(gv)))
    ||
        ((gv = gv_fetchpv("YAML::XS::LoadCode", TRUE, SVt_PV)) &&
        SvTRUE(GvSV(gv)))
    );

    loader.load_blessed = 0;
    gv = gv_fetchpv("YAML::XS::LoadBlessed", FALSE, SVt_PV);
    if (SvOK(GvSV(gv)) && SvTRUE(GvSV(gv))) {
        loader.load_blessed = 1;
    }

    loader.forbid_duplicate_keys = 0;
    gv = gv_fetchpv("YAML::XS::ForbidDuplicateKeys", FALSE, SVt_PV);
    if (SvOK(GvSV(gv)) && SvTRUE(GvSV(gv))) {
        loader.forbid_duplicate_keys = 1;
    }

    yaml_str = (const unsigned char *)SvPV_const(yaml_sv, yaml_len);

    if (DO_UTF8(yaml_sv)) {
        yaml_sv = sv_mortalcopy(yaml_sv);
        if (!sv_utf8_downgrade(yaml_sv, TRUE))
            croak("%s", "Wide character in YAML::XS::Load()");
        yaml_str = (const unsigned char *)SvPV_const(yaml_sv, yaml_len);
    }

    sp = mark;
    if (0 && (items || ax)) {} /* XXX Quiet the -Wall warnings for now. */

    yaml_parser_initialize(&loader.parser);

    loader.document = 0;
    yaml_parser_set_input_string(
        &loader.parser,
        yaml_str,
        yaml_len
    );

    /* Get the first event. Must be a STREAM_START */
    if (!yaml_parser_parse(&loader.parser, &loader.event))
        goto load_error;
    if (loader.event.type != YAML_STREAM_START_EVENT)
        croak("%sExpected STREAM_START_EVENT; Got: %d != %d",
            ERRMSG,
            loader.event.type,
            YAML_STREAM_START_EVENT
         );

    loader.anchors = newHV();
    sv_2mortal((SV *)loader.anchors);

    XCPT_TRY_START {

        /* Keep calling load_node until end of stream */
        while (1) {
            loader.document++;
            /* We are through with the previous event - delete it! */
            yaml_event_delete(&loader.event);
            if (!yaml_parser_parse(&loader.parser, &loader.event))
                goto load_error;
            if (loader.event.type == YAML_STREAM_END_EVENT)
                break;
            node = load_node(&loader);
            /* We are through with the previous event - delete it! */
            yaml_event_delete(&loader.event);
            hv_clear(loader.anchors);
            if (! node) break;
            XPUSHs(sv_2mortal(node));
            if (!yaml_parser_parse(&loader.parser, &loader.event))
                goto load_error;
            if (loader.event.type != YAML_DOCUMENT_END_EVENT)
                croak("%sExpected DOCUMENT_END_EVENT", ERRMSG);
        }

        /* Make sure the last event is a STREAM_END */
        if (loader.event.type != YAML_STREAM_END_EVENT)
            croak("%sExpected STREAM_END_EVENT; Got: %d != %d",
                ERRMSG,
                loader.event.type,
                YAML_STREAM_END_EVENT
             );

    } XCPT_TRY_END

    XCPT_CATCH
    {
        yaml_parser_delete(&loader.parser);
        XCPT_RETHROW;
    }

    yaml_parser_delete(&loader.parser);
    PUTBACK;
    return;

load_error:
    croak("%s", loader_error_msg(&loader, NULL));
}

/*
 * This is the main function for dumping any node.
 */
SV *
load_node(perl_yaml_loader_t *loader)
{
    char *tag;
    SV* return_sv = NULL;
    /* This uses stack, but avoids (severe!) memory leaks */
    yaml_event_t uplevel_event;

    uplevel_event = loader->event;

    /* Get the next parser event */
    if (!yaml_parser_parse(&loader->parser, &loader->event))
        goto load_error;

    /* These events don't need yaml_event_delete */
    /* Some kind of error occurred */
    if (loader->event.type == YAML_NO_EVENT)
        goto load_error;

    /* Return NULL when we hit the end of a scope */
    if (loader->event.type == YAML_DOCUMENT_END_EVENT ||
        loader->event.type == YAML_MAPPING_END_EVENT ||
        loader->event.type == YAML_SEQUENCE_END_EVENT) {
            /* restore the uplevel event, so it can be properly deleted */
            loader->event = uplevel_event;
            return return_sv;
    }

    /* The rest all need cleanup */
    switch (loader->event.type) {

        /* Handle loading a mapping */
        case YAML_MAPPING_START_EVENT:
            tag = (char *)loader->event.data.mapping_start.tag;

            /* Handle mapping tagged as a Perl hard reference */
            if (tag && strEQ(tag, TAG_PERL_REF)) {
                return_sv = load_scalar_ref(loader);
                break;
            }

            /* Handle mapping tagged as a Perl typeglob */
            if (tag && strEQ(tag, TAG_PERL_GLOB)) {
                return_sv = load_glob(loader);
                break;
            }

            return_sv = load_mapping(loader, NULL);
            break;

        /* Handle loading a sequence into an array */
        case YAML_SEQUENCE_START_EVENT:
            return_sv = load_sequence(loader);
            break;

        /* Handle loading a scalar */
        case YAML_SCALAR_EVENT:
            return_sv = load_scalar(loader);
            break;

        /* Handle loading an alias node */
        case YAML_ALIAS_EVENT:
            return_sv = load_alias(loader);
            break;

        default:
            croak("%sInvalid event '%d' at top level", ERRMSG, (int) loader->event.type);
    }

    yaml_event_delete(&loader->event);

    /* restore the uplevel event, so it can be properly deleted */
    loader->event = uplevel_event;

    return return_sv;

    load_error:
        croak("%s", loader_error_msg(loader, NULL));
}

/*
 * Load a YAML mapping into a Perl hash
 */
SV *
load_mapping(perl_yaml_loader_t *loader, char *tag)
{
    dXCPT;
    SV *key_node;
    SV *value_node;
    HV *hash = newHV();
    SV *hash_ref = (SV *)newRV_noinc((SV *)hash);
    char *anchor = (char *)loader->event.data.mapping_start.anchor;

    if (!tag)
        tag = (char *)loader->event.data.mapping_start.tag;

    /* Store the anchor label if any */
    if (anchor)
        hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(hash_ref), 0);

    XCPT_TRY_START {

        /* Get each key string and value node and put them in the hash */
        while ((key_node = load_node(loader))) {
            assert(SvPOK(key_node));
            value_node = load_node(loader);
            if (loader->forbid_duplicate_keys &&
                hv_exists_ent(hash, key_node, 0)
            ) {
                croak(
                    "%s",
                    loader_error_msg(
                        loader,
                        form("Duplicate key '%s'", SvPV_nolen(key_node))
                    )
                );
            }
            hv_store_ent(
                hash, sv_2mortal(key_node), value_node, 0
            );
        }

        /* Deal with possibly blessing the hash if the YAML tag has a class */
        if (tag) {
            if (strEQ(tag, TAG_PERL_PREFIX "hash")) {
            }
            else if (strEQ(tag, YAML_MAP_TAG)) {
            }
            else {
                char *class;
                char *prefix = TAG_PERL_PREFIX "hash:";
                if (*tag == '!') {
                    prefix = "!";
                }
                else if (strlen(tag) <= strlen(prefix) ||
                    ! strnEQ(tag, prefix, strlen(prefix))
                ) croak("%s",
                    loader_error_msg(loader, form("bad tag found for hash: '%s'", tag))
                );
                if (loader->load_blessed) {
                    class = tag + strlen(prefix);
                    sv_bless(hash_ref, gv_stashpv(class, TRUE));
                }
            }
        }

    } XCPT_TRY_END

    XCPT_CATCH
    {
        SvREFCNT_dec(hash_ref);
        XCPT_RETHROW;
    }

    return hash_ref;
}

/* Load a YAML sequence into a Perl array */
SV *
load_sequence(perl_yaml_loader_t *loader)
{
    dXCPT;
    SV *node;
    AV *array = newAV();
    SV *array_ref = (SV *)newRV_noinc((SV *)array);
    char *anchor = (char *)loader->event.data.sequence_start.anchor;
    char *tag = (char *)loader->event.data.mapping_start.tag;

    XCPT_TRY_START {

        if (anchor)
            hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(array_ref), 0);
        while ((node = load_node(loader))) {
            av_push(array, node);
        }

        if (tag) {
            if (strEQ(tag, TAG_PERL_PREFIX "array")) {
            }
            else if (strEQ(tag, YAML_SEQ_TAG)) {
            }
            else {
                char *class;
                char *prefix = TAG_PERL_PREFIX "array:";

                if (*tag == '!')
                    prefix = "!";
                else if (strlen(tag) <= strlen(prefix) ||
                    ! strnEQ(tag, prefix, strlen(prefix))
                ) croak("%s",
                    loader_error_msg(loader, form("bad tag found for array: '%s'", tag))
                );
                if (loader->load_blessed) {
                    class = tag + strlen(prefix);
                    sv_bless(array_ref, gv_stashpv(class, TRUE));
                }
            }
        }

    } XCPT_TRY_END

    XCPT_CATCH
    {
        SvREFCNT_dec(array_ref);
        XCPT_RETHROW;
    }

    return array_ref;
}

/* Load a YAML scalar into a Perl scalar */
SV *
load_scalar(perl_yaml_loader_t *loader)
{
    SV *scalar;
    char *string = (char *)loader->event.data.scalar.value;
    STRLEN length = (STRLEN)loader->event.data.scalar.length;
    char *anchor = (char *)loader->event.data.scalar.anchor;
    char *tag = (char *)loader->event.data.scalar.tag;
    yaml_scalar_style_t style = loader->event.data.scalar.style;
    if (tag) {
        if (strEQ(tag, YAML_STR_TAG)) {
            style = YAML_SINGLE_QUOTED_SCALAR_STYLE;
        }
        else if (strEQ(tag, YAML_INT_TAG) || strEQ(tag, YAML_FLOAT_TAG)) {
            /* TODO check int/float */
            scalar = newSVpvn(string, length);
            if ( looks_like_number(scalar) ) {
                /* numify */
                SvIV_please(scalar);
            }
            else {
                croak("%s",
                    loader_error_msg(loader, form("Invalid content found for !!int tag: '%s'", tag))
                );
            }
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
        else if (
            strEQ(tag, YAML_NULL_TAG)
            &&
            (strEQ(string, "~") || strEQ(string, "null") || strEQ(string, ""))
        ) {
            scalar = newSV(0);
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
        else {
            char *class;
            char *prefix = TAG_PERL_PREFIX "regexp";
            if (strnEQ(tag, prefix, strlen(prefix)))
                return load_regexp(loader);
            prefix = TAG_PERL_PREFIX "code";
            if (strnEQ(tag, prefix, strlen(prefix)))
                return load_code(loader);
            prefix = TAG_PERL_PREFIX "scalar:";
            if (*tag == '!')
                prefix = "!";
            else if (strlen(tag) <= strlen(prefix) ||
                ! strnEQ(tag, prefix, strlen(prefix))
            ) croak("%sbad tag found for scalar: '%s'", ERRMSG, tag);
            class = tag + strlen(prefix);
            if (loader->load_blessed)
                scalar = sv_setref_pvn(newSV(0), class, string, strlen(string));
            else
                scalar = newSVpvn(string, length);
            SvUTF8_on(scalar);
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
    }

    else if (style == YAML_PLAIN_SCALAR_STYLE) {
        if (strEQ(string, "~") || strEQ(string, "null") || strEQ(string, "")) {
            scalar = newSV(0);
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
        else if (strEQ(string, "true")) {
            if (loader->load_bool_jsonpp) {
                char *name = "JSON::PP::Boolean";
                scalar = newSV(1);
                scalar = sv_setref_iv(scalar, name, 1);
            }
            else if (loader->load_bool_boolean) {
                char *name = "boolean";
                scalar = newSV(1);
                scalar = sv_setref_iv(scalar, name, 1);
            }
            else {
                scalar = &PL_sv_yes;
            }
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
        else if (strEQ(string, "false")) {
            if (loader->load_bool_jsonpp) {
                char *name = "JSON::PP::Boolean";
                scalar = newSV(1);
                scalar = sv_setref_iv(scalar, name, 0);
            }
            else if (loader->load_bool_boolean) {
                char *name = "boolean";
                scalar = newSV(1);
                scalar = sv_setref_iv(scalar, name, 0);
            }
            else {
                scalar = &PL_sv_no;
            }
            if (anchor)
                hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
            return scalar;
        }
    }

    scalar = newSVpvn(string, length);

    if (style == YAML_PLAIN_SCALAR_STYLE && looks_like_number(scalar) ) {
        /* numify */
        SvIV_please(scalar);
    }

    (void)sv_utf8_decode(scalar);
    if (anchor)
        hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(scalar), 0);
    return scalar;
}

/* Load a scalar marked as a regexp as a Perl regular expression.
 * This operation is less common and is tricky, so doing it in Perl code for
 * now.
 */
SV *
load_regexp(perl_yaml_loader_t * loader)
{
    dSP;
    char *string = (char *)loader->event.data.scalar.value;
    STRLEN length = (STRLEN)loader->event.data.scalar.length;
    char *anchor = (char *)loader->event.data.scalar.anchor;
    char *tag = (char *)loader->event.data.scalar.tag;
    char *prefix = TAG_PERL_PREFIX "regexp:";

    SV *regexp = newSVpvn(string, length);
    SvUTF8_on(regexp);

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(regexp);
    PUTBACK;
    call_pv("YAML::XS::__qr_loader", G_SCALAR);
    SPAGAIN;
    regexp = newSVsv(POPs);

    PUTBACK;
    FREETMPS;
    LEAVE;

    if (strlen(tag) > strlen(prefix) && strnEQ(tag, prefix, strlen(prefix))) {
        if (loader->load_blessed) {
            char *class = tag + strlen(prefix);
            sv_bless(regexp, gv_stashpv(class, TRUE));
        }
    }

    if (anchor)
        hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(regexp), 0);
    return regexp;
}

/* Load a scalar marked as code as a Perl code reference.
 * This operation is less common and is tricky, so doing it in Perl code for
 * now.
 */
SV*
load_code(perl_yaml_loader_t * loader)
{
    dSP;
    char *string = (char *)loader->event.data.scalar.value;
    STRLEN length = (STRLEN)loader->event.data.scalar.length;
    char *anchor = (char *)loader->event.data.scalar.anchor;
    char *tag = (char *)loader->event.data.scalar.tag;
    char *prefix = TAG_PERL_PREFIX "code:";

    if (! loader->load_code) {
        string = "{}";
        length = 2;
    }
    SV *code = newSVpvn(string, length);
    SvUTF8_on(code);


    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    XPUSHs(code);
    PUTBACK;
    call_pv("YAML::XS::__code_loader", G_SCALAR);
    SPAGAIN;
    code = newSVsv(POPs);

    PUTBACK;
    FREETMPS;
    LEAVE;

    if (strlen(tag) > strlen(prefix) && strnEQ(tag, prefix, strlen(prefix))) {
        if (loader->load_blessed) {
            char *class = tag + strlen(prefix);
            sv_bless(code, gv_stashpv(class, TRUE));
        }
    }

    if (anchor)
        hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(code), 0);
    return code;
}


/*
 * Load a reference to a previously loaded node.
 */
SV *
load_alias(perl_yaml_loader_t *loader)
{
    char *anchor = (char *)loader->event.data.alias.anchor;
    SV **entry = hv_fetch(loader->anchors, anchor, strlen(anchor), 0);
    if (entry)
        return SvREFCNT_inc(*entry);
    croak("%sNo anchor for alias '%s'", ERRMSG, anchor);
}

/*
 * Load a Perl hard reference.
 */
SV *
load_scalar_ref(perl_yaml_loader_t *loader)
{
    SV *value_node;
    char *anchor = (char *)loader->event.data.mapping_start.anchor;
    SV *rv = newRV_noinc(&PL_sv_undef);
    if (anchor)
        hv_store(loader->anchors, anchor, strlen(anchor), SvREFCNT_inc(rv), 0);
    load_node(loader);  /* Load the single hash key (=) */
    value_node = load_node(loader);
    SvRV(rv) = value_node;
    if (load_node(loader))
        croak("%sExpected end of node", ERRMSG);
    return rv;
}

/*
 * Load a Perl typeglob.
 */
SV *
load_glob(perl_yaml_loader_t *loader)
{
    /* XXX Call back a Perl sub to do something interesting here */
    return load_mapping(loader, TAG_PERL_PREFIX "hash");
}

/* -------------------------------------------------------------------------- */

/*
 * Set dumper options from global variables.
 */
void
set_dumper_options(perl_yaml_dumper_t *dumper)
{
    GV *gv;
    char* boolean = "";
    dumper->dump_code = (
        ((gv = gv_fetchpv("YAML::XS::UseCode", TRUE, SVt_PV)) &&
        SvTRUE(GvSV(gv)))
    ||
        ((gv = gv_fetchpv("YAML::XS::DumpCode", TRUE, SVt_PV)) &&
        SvTRUE(GvSV(gv)))
    );

    dumper->quote_number_strings = (
        ((gv = gv_fetchpv("YAML::XS::QuoteNumericStrings", TRUE, SVt_PV)) &&
        SvTRUE(GvSV(gv)))
    );

    gv = gv_fetchpv("YAML::XS::Boolean", FALSE, SVt_PV);
    dumper->dump_bool_jsonpp = 0;
    dumper->dump_bool_boolean = 0;
    if (SvTRUE(GvSV(gv))) {
        boolean = SvPV_nolen(GvSV(gv));
        if (strEQ(boolean, "JSON::PP")) {
            dumper->dump_bool_jsonpp = 1;
            load_module(PERL_LOADMOD_NOIMPORT, newSVpv("JSON::PP", 0), Nullsv);
        }
        else if (strEQ(boolean, "boolean")) {
            dumper->dump_bool_boolean = 1;
            load_module(PERL_LOADMOD_NOIMPORT, newSVpv("boolean", 0), Nullsv);
        }
        else {
            croak("%s",
                "$YAML::XS::Boolean only accepts 'JSON::PP', 'boolean' or a false value");
        }
    }

    /* dumper->emitter.open_ended = 1;
     */
}

/*
 * This is the main Dump function.
 * Take zero or more Perl objects and return a YAML stream (as a string)
 */
void
Dump(SV *dummy, ...)
{
    dXSARGS;
    perl_yaml_dumper_t dumper;
    yaml_event_t event_stream_start;
    yaml_event_t event_stream_end;
    int i;
    SV *yaml = sv_2mortal(newSVpvn("", 0));
    sp = mark;

    set_dumper_options(&dumper);

    /* Set up the emitter object and begin emitting */
    yaml_emitter_initialize(&dumper.emitter);

    /* set indent */
    SV* indent = get_sv("YAML::XS::Indent", GV_ADD);
    if (SvIOK(indent)) yaml_emitter_set_indent(&dumper.emitter, SvIV(indent));

    yaml_emitter_set_unicode(&dumper.emitter, 1);
    yaml_emitter_set_width(&dumper.emitter, 2);
    yaml_emitter_set_output(
        &dumper.emitter,
        &append_output,
        (void *) yaml
    );
    yaml_stream_start_event_initialize(
        &event_stream_start,
        YAML_UTF8_ENCODING
    );
    yaml_emitter_emit(&dumper.emitter, &event_stream_start);

    dumper.anchors = newHV();
    dumper.shadows = newHV();

    sv_2mortal((SV *)dumper.anchors);
    sv_2mortal((SV *)dumper.shadows);

    for (i = 0; i < items; i++) {
        dumper.anchor = 0;

        dump_prewalk(&dumper, ST(i));
        dump_document(&dumper, ST(i));

        hv_clear(dumper.anchors);
        hv_clear(dumper.shadows);
    }

    /* End emitting and destroy the emitter object */
    yaml_stream_end_event_initialize(&event_stream_end);
    yaml_emitter_emit(&dumper.emitter, &event_stream_end);
    yaml_emitter_delete(&dumper.emitter);

    /* Put the YAML stream scalar on the XS output stack */
    if (yaml) {
        SvUTF8_off(yaml);
        XPUSHs(yaml);
    }
    PUTBACK;
}

/*
 * In order to know which nodes will need anchors (for later aliasing) it is
 * necessary to walk the entire data structure first. Once a node has been
 * seen twice you can stop walking it. That way we can handle circular refs.
 * All the node information is stored in an HV.
 */
void
dump_prewalk(perl_yaml_dumper_t *dumper, SV *node)
{
    int i, len;
    U32 ref_type;
    SvGETMAGIC(node);

    if (! (SvROK(node) || SvTYPE(node) == SVt_PVGV)) return;

    {
        SV *object = SvROK(node) ? SvRV(node) : node;
        SV **seen =
            hv_fetch(dumper->anchors, (char *)&object, sizeof(object), 0);
        if (seen) {
            if (*seen == &PL_sv_undef) {
                hv_store(
                    dumper->anchors, (char *)&object, sizeof(object),
                    &PL_sv_yes, 0
                );
            }
            return;
        }
        hv_store(
            dumper->anchors, (char *)&object, sizeof(object), &PL_sv_undef, 0
        );
    }

    if (SvTYPE(node) == SVt_PVGV) {
        node = dump_glob(dumper, node);
    }

    ref_type = SvTYPE(SvRV(node));
    if (ref_type == SVt_PVAV) {
        AV *array = (AV *)SvRV(node);
        int array_size = av_len(array) + 1;
        for (i = 0; i < array_size; i++) {
            SV **entry = av_fetch(array, i, 0);
            if (entry)
                dump_prewalk(dumper, *entry);
        }
    }
    else if (ref_type == SVt_PVHV) {
        HV *hash = (HV *)SvRV(node);
        HE *he;
        SV *key;
        SV *val;
        hv_iterinit(hash);

        while ((he = hv_iternext(hash))) {
            key = hv_iterkeysv(he);
            he = hv_fetch_ent(hash, key, 0, 0);
            val = he ? HeVAL(he) : NULL;
            if (val) {
                dump_prewalk(dumper, val);
            }
        }
    }
    else if (ref_type <= SVt_PVNV || ref_type == SVt_PVGV) {
        SV *scalar = SvRV(node);
        dump_prewalk(dumper, scalar);
    }
}

void
dump_document(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_event_t event_document_start;
    yaml_event_t event_document_end;
    yaml_document_start_event_initialize(
        &event_document_start, NULL, NULL, NULL, 0
    );
    yaml_emitter_emit(&dumper->emitter, &event_document_start);
    dump_node(dumper, node);
    yaml_document_end_event_initialize(&event_document_end, 1);
    yaml_emitter_emit(&dumper->emitter, &event_document_end);
}

void
dump_node(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_char_t *anchor = NULL;
    yaml_char_t *tag = NULL;
    const char *class = NULL;

    SvGETMAGIC(node);
    if (SvTYPE(node) == SVt_PVGV) {
        SV **svr;
        tag = (yaml_char_t *)TAG_PERL_PREFIX "glob";
        anchor = get_yaml_anchor(dumper, node);
        if (anchor && strEQ((char *)anchor, "")) return;
        svr = hv_fetch(dumper->shadows, (char *)&node, sizeof(node), 0);
        if (svr) {
            node = SvREFCNT_inc(*svr);
        }
    }

    if (SvROK(node)) {
        SV *rnode = SvRV(node);
        U32 ref_type = SvTYPE(rnode);
        if (ref_type == SVt_PVHV)
            dump_hash(dumper, node, anchor, tag);
        else if (ref_type == SVt_PVAV)
            dump_array(dumper, node);
        else if (ref_type <= SVt_PVNV || ref_type == SVt_PVGV)
            dump_ref(dumper, node);
        else if (ref_type == SVt_PVCV)
            dump_code(dumper, node);
        else if (ref_type == SVt_PVMG) {
            MAGIC *mg;
            yaml_char_t *tag = NULL;
            if (SvMAGICAL(rnode)) {
                if ((mg = mg_find(rnode, PERL_MAGIC_qr))) {
                    tag = (yaml_char_t *)form(TAG_PERL_PREFIX "regexp");
                    class = sv_reftype(rnode, TRUE);
                    if (!strEQ(class, "Regexp"))
                        tag = (yaml_char_t *)form("%s:%s", tag, class);
                }
                dump_scalar(dumper, node, tag);
            }
            else {
                class = sv_reftype(rnode, TRUE);
                if (
                        dumper->dump_bool_jsonpp
                        && strEQ(class, "JSON::PP::Boolean")
                    ||
                        dumper->dump_bool_boolean
                        && strEQ(class, "boolean")
                    ) {
                    if (SvIV(node)) {
                        dump_scalar(dumper, &PL_sv_yes, NULL);
                    }
                    else {
                        dump_scalar(dumper, &PL_sv_no, NULL);
                    }
                }
                else {
                    tag = (yaml_char_t *)form(
                        TAG_PERL_PREFIX "scalar:%s",
                        class
                    );
                    node = rnode;
                    dump_scalar(dumper, node, tag);
                }
            }
        }
#if PERL_REVISION > 5 || (PERL_REVISION == 5 && PERL_VERSION >= 11)
        else if (ref_type == SVt_REGEXP) {
            yaml_char_t *tag = (yaml_char_t *)form(TAG_PERL_PREFIX "regexp");
            class = sv_reftype(rnode, TRUE);
                if (!strEQ(class, "Regexp"))
                     tag = (yaml_char_t *)form("%s:%s", tag, class);
            dump_scalar(dumper, node, tag);
        }
#endif
        else {
            printf(
                "YAML::XS dump unhandled ref. type == '%d'!\n",
                (int)ref_type
            );
            dump_scalar(dumper, rnode, NULL);
        }
    }
    else {
        dump_scalar(dumper, node, NULL);
    }
}

yaml_char_t *
get_yaml_anchor(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_event_t event_alias;
    SV *iv;
    SV **seen = hv_fetch(dumper->anchors, (char *)&node, sizeof(node), 0);
    if (seen && *seen != &PL_sv_undef) {
        if (*seen == &PL_sv_yes) {
            dumper->anchor++;
            iv = newSViv(dumper->anchor);
            hv_store(dumper->anchors, (char *)&node, sizeof(node), iv, 0);
            return (yaml_char_t*)SvPV_nolen(iv);
        }
        else {
            yaml_char_t *anchor = (yaml_char_t *)SvPV_nolen(*seen);
            yaml_alias_event_initialize(&event_alias, anchor);
            yaml_emitter_emit(&dumper->emitter, &event_alias);
            return (yaml_char_t *) "";
        }
    }
    return NULL;
}

yaml_char_t *
get_yaml_tag(SV *node)
{
    yaml_char_t *tag;
    const char *class;
    const char *kind = "";
    if (! (
        sv_isobject(node) ||
        (SvRV(node) && ( SvTYPE(SvRV(node)) == SVt_PVCV))
    )) return NULL;
    class = sv_reftype(SvRV(node), TRUE);

    switch (SvTYPE(SvRV(node))) {
        case SVt_PVAV: { kind = "array"; break; }
        case SVt_PVHV: { kind = "hash"; break; }
        case SVt_PVCV: { kind = "code"; break; }
    }
    if ((strlen(kind) == 0))
        tag = (yaml_char_t *)form("%s%s", TAG_PERL_PREFIX, class);
    else if (SvTYPE(SvRV(node)) == SVt_PVCV && strEQ(class, "CODE"))
        tag = (yaml_char_t *)form("%s%s", TAG_PERL_PREFIX, kind);
    else
        tag = (yaml_char_t *)form("%s%s:%s", TAG_PERL_PREFIX, kind, class);
    return tag;
}

void
dump_hash(
    perl_yaml_dumper_t *dumper, SV *node,
    yaml_char_t *anchor, yaml_char_t *tag)
{
    yaml_event_t event_mapping_start;
    yaml_event_t event_mapping_end;
    int i;
    int len;
    AV *av;
    HV *hash = (HV *)SvRV(node);
    HE *he;

    if (!anchor)
        anchor = get_yaml_anchor(dumper, (SV *)hash);
    if (anchor && strEQ((char*)anchor, "")) return;

    if (!tag)
        tag = get_yaml_tag(node);

    yaml_mapping_start_event_initialize(
        &event_mapping_start, anchor, tag, 0, YAML_BLOCK_MAPPING_STYLE
    );
    yaml_emitter_emit(&dumper->emitter, &event_mapping_start);

    av = newAV();
    len = 0;
    hv_iterinit(hash);
    while ((he = hv_iternext(hash))) {
        SV *key = hv_iterkeysv(he);
        av_store(av, AvFILLp(av)+1, key); /* av_push(), really */
        len++;
    }
    STORE_HASH_SORT;
    for (i = 0; i < len; i++) {
        SV *key = av_shift(av);
        HE *he  = hv_fetch_ent(hash, key, 0, 0);
        SV *val = he ? HeVAL(he) : NULL;
        if (val == NULL) { val = &PL_sv_undef; }
        dump_node(dumper, key);
        dump_node(dumper, val);
    }

    SvREFCNT_dec(av);

    yaml_mapping_end_event_initialize(&event_mapping_end);
    yaml_emitter_emit(&dumper->emitter, &event_mapping_end);
}

void
dump_array(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_event_t event_sequence_start;
    yaml_event_t event_sequence_end;
    int i;
    yaml_char_t *tag;
    AV *array = (AV *)SvRV(node);
    int array_size = av_len(array) + 1;

    yaml_char_t *anchor = get_yaml_anchor(dumper, (SV *)array);
    if (anchor && strEQ((char *)anchor, "")) return;
    tag = get_yaml_tag(node);

    yaml_sequence_start_event_initialize(
        &event_sequence_start, anchor, tag, 0, YAML_BLOCK_SEQUENCE_STYLE
    );

    yaml_emitter_emit(&dumper->emitter, &event_sequence_start);
    for (i = 0; i < array_size; i++) {
        SV **entry = av_fetch(array, i, 0);
        if (entry == NULL)
            dump_node(dumper, &PL_sv_undef);
        else
            dump_node(dumper, *entry);
    }
    yaml_sequence_end_event_initialize(&event_sequence_end);
    yaml_emitter_emit(&dumper->emitter, &event_sequence_end);
}

void
dump_scalar(perl_yaml_dumper_t *dumper, SV *node, yaml_char_t *tag)
{
    yaml_event_t event_scalar;
    char *string;
    STRLEN string_len;
    int plain_implicit, quoted_implicit;
    yaml_scalar_style_t style = YAML_PLAIN_SCALAR_STYLE;

    if (tag) {
        plain_implicit = quoted_implicit = 0;
    }
    else {
        tag = (yaml_char_t *)TAG_PERL_STR;
        plain_implicit = quoted_implicit = 1;
    }

    SvGETMAGIC(node);
    if (!SvOK(node)) {
        string = "~";
        string_len = 1;
        style = YAML_PLAIN_SCALAR_STYLE;
    }
    else if (node == &PL_sv_yes) {
        string = "true";
        string_len = 4;
        style = YAML_PLAIN_SCALAR_STYLE;
    }
    else if (node == &PL_sv_no) {
        string = "false";
        string_len = 5;
        style = YAML_PLAIN_SCALAR_STYLE;
    }
    else {
        SV *node_clone = sv_mortalcopy(node);
        string = SvPV_nomg(node_clone, string_len);
        if (
            (string_len == 0) ||
            (string_len == 1 && strEQ(string, "~")) ||
            (string_len == 4 && strEQ(string, "true")) ||
            (string_len == 5 && strEQ(string, "false")) ||
            (string_len == 4 && strEQ(string, "null")) ||
            (SvTYPE(node_clone) >= SVt_PVGV) ||
            ( dumper->quote_number_strings && !SvNIOK(node_clone) && looks_like_number(node_clone) )
        ) {
            style = YAML_SINGLE_QUOTED_SCALAR_STYLE;
        } else {
            if (!SvUTF8(node_clone)) {
            /* copy to new SV and promote to utf8 */
            SV *utf8sv = sv_mortalcopy(node_clone);

            /* get string and length out of utf8 */
            string = SvPVutf8(utf8sv, string_len);
            }
            if(strchr(string, '\n'))
               style = (string_len > 30) ? YAML_LITERAL_SCALAR_STYLE : YAML_DOUBLE_QUOTED_SCALAR_STYLE;
        }
    }
    if (! yaml_scalar_event_initialize(
        &event_scalar,
        NULL,
        tag,
        (unsigned char *) string,
        (int) string_len,
        plain_implicit,
        quoted_implicit,
        style
    )) {
        croak("Could not initialize scalar event\n");
    }
    if (! yaml_emitter_emit(&dumper->emitter, &event_scalar))
        croak("%sEmit scalar '%s', error: %s\n",
            ERRMSG,
            string, dumper->emitter.problem
        );
}

void
dump_code(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_event_t event_scalar;
    yaml_char_t *tag;
    yaml_scalar_style_t style = YAML_SINGLE_QUOTED_SCALAR_STYLE;
    char *string = "{ \"DUMMY\" }";
    if (dumper->dump_code) {
        /* load_module(PERL_LOADMOD_NOIMPORT, newSVpv("B::Deparse", 0), NULL);
         */
        SV *result;
        SV *code = find_coderef("YAML::XS::coderef2text");
        AV *args = newAV();
        av_push(args, SvREFCNT_inc(node));
        args = (AV *)sv_2mortal((SV *)args);
        result = call_coderef(code, args);
        if (result && result != &PL_sv_undef) {
            string = SvPV_nolen(result);
            style = YAML_LITERAL_SCALAR_STYLE;
        }
    }
    tag = get_yaml_tag(node);

    yaml_scalar_event_initialize(
        &event_scalar,
        NULL,
        tag,
        (unsigned char *)string,
        strlen(string),
        0,
        0,
        style
    );

    yaml_emitter_emit(&dumper->emitter, &event_scalar);
}

SV *
dump_glob(perl_yaml_dumper_t *dumper, SV *node)
{
    SV *result;
    SV *code = find_coderef("YAML::XS::glob2hash");
    AV *args = newAV();
    av_push(args, SvREFCNT_inc(node));
    args = (AV *)sv_2mortal((SV *)args);
    result = call_coderef(code, args);
    hv_store(
        dumper->shadows, (char *)&node, sizeof(node),
        result, 0
    );
    return result;
}

/* XXX Refo this to just dump a special map */
void
dump_ref(perl_yaml_dumper_t *dumper, SV *node)
{
    yaml_event_t event_mapping_start;
    yaml_event_t event_mapping_end;
    yaml_event_t event_scalar;
    SV *referent = SvRV(node);

    yaml_char_t *anchor = get_yaml_anchor(dumper, referent);
    if (anchor && strEQ((char *)anchor, "")) return;

    yaml_mapping_start_event_initialize(
        &event_mapping_start, anchor,
        (unsigned char *)TAG_PERL_PREFIX "ref",
        0, YAML_BLOCK_MAPPING_STYLE
    );
    yaml_emitter_emit(&dumper->emitter, &event_mapping_start);

    yaml_scalar_event_initialize(
        &event_scalar,
        NULL, NULL,
        (unsigned char *)"=", 1,
        1, 1,
        YAML_PLAIN_SCALAR_STYLE
    );
    yaml_emitter_emit(&dumper->emitter, &event_scalar);
    dump_node(dumper, referent);

    yaml_mapping_end_event_initialize(&event_mapping_end);
    yaml_emitter_emit(&dumper->emitter, &event_mapping_end);
}

int
append_output(void *yaml, unsigned char *buffer, size_t size)
{
    sv_catpvn((SV *)yaml, (const char *)buffer, (STRLEN)size);
    return 1;
}

/* XXX Make -Wall not complain about 'local_patches' not being used. */
#if !defined(PERL_PATCHLEVEL_H_IMPLICIT)
void xxx_local_patches() {
    printf("%s", local_patches[0]);
}
#endif
