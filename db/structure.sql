SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: spanish_unaccent; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.spanish_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR asciiword WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR word WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR hword_asciipart WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR asciihword WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.spanish_unaccent
    ADD MAPPING FOR uint WITH simple;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    user_id bigint,
    account_type character varying DEFAULT 'user'::character varying NOT NULL,
    cached_balance integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    territory_id bigint
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: announcement_supports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_supports (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: announcement_supports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_supports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_supports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_supports_id_seq OWNED BY public.announcement_supports.id;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id bigint NOT NULL,
    title character varying NOT NULL,
    slug character varying NOT NULL,
    body text NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    published_at timestamp(6) without time zone,
    user_id bigint NOT NULL,
    supports_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: announcements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcements_id_seq OWNED BY public.announcements.id;


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying DEFAULT 'Mi web'::character varying NOT NULL,
    token_digest character varying NOT NULL,
    prefix character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    trust_weight integer DEFAULT 1 NOT NULL,
    allows_credit boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    max_credit_multiplier numeric(4,2) DEFAULT 1.0 NOT NULL,
    publishable boolean DEFAULT true NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    hidden_at timestamp(6) without time zone
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id bigint NOT NULL,
    participant_a_id bigint NOT NULL,
    participant_b_id bigint NOT NULL,
    last_message_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: credit_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_transactions (
    id bigint NOT NULL,
    interaction_id bigint,
    uuid character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    total_amount integer NOT NULL,
    burn_amount integer DEFAULT 0 NOT NULL,
    community_amount integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    territory_id bigint,
    category_id bigint,
    source_type character varying,
    source_id bigint
);


--
-- Name: credit_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_transactions_id_seq OWNED BY public.credit_transactions.id;


--
-- Name: direct_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_messages (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    user_id bigint NOT NULL,
    body text NOT NULL,
    hidden_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: direct_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_messages_id_seq OWNED BY public.direct_messages.id;


--
-- Name: disputes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disputes (
    id bigint NOT NULL,
    interaction_id bigint NOT NULL,
    opener_id bigint NOT NULL,
    argument text NOT NULL,
    response text,
    responded_at timestamp(6) without time zone,
    status integer DEFAULT 0 NOT NULL,
    verdict integer,
    resolution_amount integer,
    resolution_note text,
    resolved_by_id bigint,
    resolved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: disputes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.disputes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: disputes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.disputes_id_seq OWNED BY public.disputes.id;


--
-- Name: economic_parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economic_parameters (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value character varying NOT NULL,
    description text,
    updated_by_user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    territory_id bigint
);


--
-- Name: economic_parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.economic_parameters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: economic_parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.economic_parameters_id_seq OWNED BY public.economic_parameters.id;


--
-- Name: endorsements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endorsements (
    id bigint NOT NULL,
    endorser_id bigint NOT NULL,
    endorsed_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: endorsements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.endorsements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: endorsements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.endorsements_id_seq OWNED BY public.endorsements.id;


--
-- Name: feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedbacks (
    id bigint NOT NULL,
    user_id bigint,
    kind integer DEFAULT 0 NOT NULL,
    body text NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    url character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: feedbacks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feedbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feedbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feedbacks_id_seq OWNED BY public.feedbacks.id;


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    sluggable_id integer NOT NULL,
    sluggable_type character varying(50),
    scope character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: identity_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_verifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    note text,
    reviewed_by_id bigint,
    reviewed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: identity_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_verifications_id_seq OWNED BY public.identity_verifications.id;


--
-- Name: interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interactions (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    sender_id bigint NOT NULL,
    receiver_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    agreed_credits integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sender_completed_at timestamp(6) without time zone,
    receiver_completed_at timestamp(6) without time zone
);


--
-- Name: interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interactions_id_seq OWNED BY public.interactions.id;


--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id bigint NOT NULL,
    credit_transaction_id bigint NOT NULL,
    account_id bigint NOT NULL,
    amount integer NOT NULL,
    direction character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ledger_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ledger_entries_id_seq OWNED BY public.ledger_entries.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    interaction_id bigint NOT NULL,
    user_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    hidden_at timestamp(6) without time zone
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    recipient_id bigint NOT NULL,
    actor_id bigint,
    notifiable_type character varying NOT NULL,
    notifiable_id bigint NOT NULL,
    kind character varying NOT NULL,
    body text NOT NULL,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: oauth_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_identities (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    provider character varying NOT NULL,
    uid character varying NOT NULL,
    email character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: oauth_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_identities_id_seq OWNED BY public.oauth_identities.id;


--
-- Name: page_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_views (
    id bigint NOT NULL,
    visited_on date NOT NULL,
    path character varying NOT NULL,
    visitor_digest character varying NOT NULL,
    logged_in boolean DEFAULT false NOT NULL,
    referrer_host character varying,
    utm_source character varying,
    utm_campaign character varying,
    app boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: page_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.page_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: page_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.page_views_id_seq OWNED BY public.page_views.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category_id bigint NOT NULL,
    title character varying NOT NULL,
    slug character varying,
    description text,
    latitude double precision,
    longitude double precision,
    status integer DEFAULT 0 NOT NULL,
    kind character varying NOT NULL,
    visibility_radius integer DEFAULT 5000 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    suggested_credits integer,
    hidden_at timestamp(6) without time zone,
    difundir boolean DEFAULT false NOT NULL,
    searchable tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('public.spanish_unaccent'::regconfig, (COALESCE(title, ''::character varying))::text), 'A'::"char") || setweight(to_tsvector('public.spanish_unaccent'::regconfig, COALESCE(description, ''::text)), 'B'::"char"))) STORED,
    pedido boolean DEFAULT false NOT NULL
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: proposal_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proposal_votes (
    id bigint NOT NULL,
    proposal_id bigint NOT NULL,
    user_id bigint NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: proposal_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.proposal_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proposal_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.proposal_votes_id_seq OWNED BY public.proposal_votes.id;


--
-- Name: proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proposals (
    id bigint NOT NULL,
    territory_id bigint NOT NULL,
    proposer_id bigint NOT NULL,
    beneficiary_id bigint,
    execution_credit_transaction_id bigint,
    title character varying NOT NULL,
    body text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    voting_closes_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.proposals_id_seq OWNED BY public.proposals.id;


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    endpoint text NOT NULL,
    p256dh character varying NOT NULL,
    auth character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.push_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.push_subscriptions_id_seq OWNED BY public.push_subscriptions.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id bigint NOT NULL,
    reporter_id bigint NOT NULL,
    reportable_type character varying NOT NULL,
    reportable_id bigint NOT NULL,
    reason integer DEFAULT 0 NOT NULL,
    body text,
    status integer DEFAULT 0 NOT NULL,
    resolved_by_id bigint,
    resolved_at timestamp(6) without time zone,
    resolution_note text,
    reward_credits integer DEFAULT 0 NOT NULL,
    territory_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id bigint NOT NULL,
    reviewer_id bigint NOT NULL,
    reviewed_user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    score integer NOT NULL,
    comment text,
    category_weight integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    interaction_id bigint NOT NULL,
    category_id bigint NOT NULL
);


--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    query character varying,
    category_id bigint,
    kind character varying,
    market character varying,
    credits_max integer,
    radius_km integer,
    latitude double precision,
    longitude double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: saved_searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_searches_id_seq OWNED BY public.saved_searches.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: social_broadcasts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_broadcasts (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    network character varying NOT NULL,
    status character varying DEFAULT 'pendiente'::character varying NOT NULL,
    external_id character varying,
    error_message character varying,
    sent_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: social_broadcasts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.social_broadcasts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: social_broadcasts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.social_broadcasts_id_seq OWNED BY public.social_broadcasts.id;


--
-- Name: territories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.territories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    country_code character varying(2) NOT NULL,
    admin1 character varying,
    admin2 character varying,
    latitude double precision,
    longitude double precision,
    source character varying DEFAULT 'admin'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: territories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.territories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: territories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.territories_id_seq OWNED BY public.territories.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    username character varying,
    slug character varying,
    bio text,
    latitude double precision,
    longitude double precision,
    trust_score numeric(4,2) DEFAULT 3.0 NOT NULL,
    territory_score integer DEFAULT 0 NOT NULL,
    verification_level integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    sponsor_id bigint,
    level integer DEFAULT 1 NOT NULL,
    credit_floor integer DEFAULT 100 NOT NULL,
    credit_ceiling integer DEFAULT 1000 NOT NULL,
    tx_cap integer DEFAULT 50 NOT NULL,
    email_verified_at timestamp(6) without time zone,
    sponsor_bonus_floor integer DEFAULT 0 NOT NULL,
    onboarding_completed_at timestamp(6) without time zone,
    admin boolean DEFAULT false NOT NULL,
    showcase boolean DEFAULT false NOT NULL,
    headline character varying,
    searchable tsvector GENERATED ALWAYS AS (((setweight(to_tsvector('public.spanish_unaccent'::regconfig, (COALESCE(username, ''::character varying))::text), 'A'::"char") || setweight(to_tsvector('public.spanish_unaccent'::regconfig, (COALESCE(headline, ''::character varying))::text), 'A'::"char")) || setweight(to_tsvector('public.spanish_unaccent'::regconfig, COALESCE(bio, ''::text)), 'B'::"char"))) STORED,
    match_notifications boolean DEFAULT true NOT NULL,
    match_radius_km integer DEFAULT 25 NOT NULL,
    match_category_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    moderator_since timestamp(6) without time zone,
    whatsapp character varying,
    horario character varying,
    vitrina_plantilla character varying,
    accent_color character varying,
    vitrina_links jsonb DEFAULT '{}'::jsonb NOT NULL,
    reactivation_sent_at timestamp(6) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: announcement_supports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_supports ALTER COLUMN id SET DEFAULT nextval('public.announcement_supports_id_seq'::regclass);


--
-- Name: announcements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements ALTER COLUMN id SET DEFAULT nextval('public.announcements_id_seq'::regclass);


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: credit_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions ALTER COLUMN id SET DEFAULT nextval('public.credit_transactions_id_seq'::regclass);


--
-- Name: direct_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_messages ALTER COLUMN id SET DEFAULT nextval('public.direct_messages_id_seq'::regclass);


--
-- Name: disputes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes ALTER COLUMN id SET DEFAULT nextval('public.disputes_id_seq'::regclass);


--
-- Name: economic_parameters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_parameters ALTER COLUMN id SET DEFAULT nextval('public.economic_parameters_id_seq'::regclass);


--
-- Name: endorsements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endorsements ALTER COLUMN id SET DEFAULT nextval('public.endorsements_id_seq'::regclass);


--
-- Name: feedbacks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks ALTER COLUMN id SET DEFAULT nextval('public.feedbacks_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: identity_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_verifications ALTER COLUMN id SET DEFAULT nextval('public.identity_verifications_id_seq'::regclass);


--
-- Name: interactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions ALTER COLUMN id SET DEFAULT nextval('public.interactions_id_seq'::regclass);


--
-- Name: ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.ledger_entries_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: oauth_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities ALTER COLUMN id SET DEFAULT nextval('public.oauth_identities_id_seq'::regclass);


--
-- Name: page_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_views ALTER COLUMN id SET DEFAULT nextval('public.page_views_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: proposal_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposal_votes ALTER COLUMN id SET DEFAULT nextval('public.proposal_votes_id_seq'::regclass);


--
-- Name: proposals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals ALTER COLUMN id SET DEFAULT nextval('public.proposals_id_seq'::regclass);


--
-- Name: push_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.push_subscriptions_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: saved_searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches ALTER COLUMN id SET DEFAULT nextval('public.saved_searches_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: social_broadcasts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_broadcasts ALTER COLUMN id SET DEFAULT nextval('public.social_broadcasts_id_seq'::regclass);


--
-- Name: territories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.territories ALTER COLUMN id SET DEFAULT nextval('public.territories_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: announcement_supports announcement_supports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_supports
    ADD CONSTRAINT announcement_supports_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: credit_transactions credit_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_pkey PRIMARY KEY (id);


--
-- Name: direct_messages direct_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT direct_messages_pkey PRIMARY KEY (id);


--
-- Name: disputes disputes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT disputes_pkey PRIMARY KEY (id);


--
-- Name: economic_parameters economic_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_parameters
    ADD CONSTRAINT economic_parameters_pkey PRIMARY KEY (id);


--
-- Name: endorsements endorsements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endorsements
    ADD CONSTRAINT endorsements_pkey PRIMARY KEY (id);


--
-- Name: feedbacks feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks
    ADD CONSTRAINT feedbacks_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: identity_verifications identity_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_verifications
    ADD CONSTRAINT identity_verifications_pkey PRIMARY KEY (id);


--
-- Name: interactions interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: oauth_identities oauth_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities
    ADD CONSTRAINT oauth_identities_pkey PRIMARY KEY (id);


--
-- Name: page_views page_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_views
    ADD CONSTRAINT page_views_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: proposal_votes proposal_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposal_votes
    ADD CONSTRAINT proposal_votes_pkey PRIMARY KEY (id);


--
-- Name: proposals proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: social_broadcasts social_broadcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_broadcasts
    ADD CONSTRAINT social_broadcasts_pkey PRIMARY KEY (id);


--
-- Name: territories territories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.territories
    ADD CONSTRAINT territories_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_accounts_one_community_per_territory; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_one_community_per_territory ON public.accounts USING btree (territory_id) WHERE (((account_type)::text = 'community'::text) AND (territory_id IS NOT NULL));


--
-- Name: idx_accounts_one_global_per_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_one_global_per_type ON public.accounts USING btree (account_type) WHERE ((account_type)::text = ANY ((ARRAY['burn'::character varying, 'system'::character varying])::text[]));


--
-- Name: idx_accounts_one_user_per_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_one_user_per_user_id ON public.accounts USING btree (user_id) WHERE (((account_type)::text = 'user'::text) AND (user_id IS NOT NULL));


--
-- Name: index_accounts_on_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_territory_id ON public.accounts USING btree (territory_id);


--
-- Name: index_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_user_id ON public.accounts USING btree (user_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_announcement_supports_on_announcement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_supports_on_announcement_id ON public.announcement_supports USING btree (announcement_id);


--
-- Name: index_announcement_supports_on_announcement_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_announcement_supports_on_announcement_id_and_user_id ON public.announcement_supports USING btree (announcement_id, user_id);


--
-- Name: index_announcement_supports_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_supports_on_user_id ON public.announcement_supports USING btree (user_id);


--
-- Name: index_announcements_on_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_published_at ON public.announcements USING btree (published_at);


--
-- Name: index_announcements_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_announcements_on_slug ON public.announcements USING btree (slug);


--
-- Name: index_announcements_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_user_id ON public.announcements USING btree (user_id);


--
-- Name: index_api_keys_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_token_digest ON public.api_keys USING btree (token_digest);


--
-- Name: index_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_name ON public.categories USING btree (name);


--
-- Name: index_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_slug ON public.categories USING btree (slug);


--
-- Name: index_comments_on_hidden_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_hidden_at ON public.comments USING btree (hidden_at);


--
-- Name: index_comments_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_post_id ON public.comments USING btree (post_id);


--
-- Name: index_comments_on_post_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_post_id_and_created_at ON public.comments USING btree (post_id, created_at);


--
-- Name: index_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);


--
-- Name: index_conversations_on_participant_a_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_participant_a_id ON public.conversations USING btree (participant_a_id);


--
-- Name: index_conversations_on_participant_a_id_and_participant_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_conversations_on_participant_a_id_and_participant_b_id ON public.conversations USING btree (participant_a_id, participant_b_id);


--
-- Name: index_conversations_on_participant_b_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_participant_b_id ON public.conversations USING btree (participant_b_id);


--
-- Name: index_credit_transactions_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_transactions_on_category_id ON public.credit_transactions USING btree (category_id);


--
-- Name: index_credit_transactions_on_interaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_transactions_on_interaction_id ON public.credit_transactions USING btree (interaction_id);


--
-- Name: index_credit_transactions_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_transactions_on_source ON public.credit_transactions USING btree (source_type, source_id);


--
-- Name: index_credit_transactions_on_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_transactions_on_territory_id ON public.credit_transactions USING btree (territory_id);


--
-- Name: index_credit_transactions_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_credit_transactions_on_uuid ON public.credit_transactions USING btree (uuid);


--
-- Name: index_direct_messages_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_messages_on_conversation_id ON public.direct_messages USING btree (conversation_id);


--
-- Name: index_direct_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_messages_on_user_id ON public.direct_messages USING btree (user_id);


--
-- Name: index_disputes_on_interaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_disputes_on_interaction_id ON public.disputes USING btree (interaction_id);


--
-- Name: index_disputes_on_opener_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disputes_on_opener_id ON public.disputes USING btree (opener_id);


--
-- Name: index_disputes_on_resolved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disputes_on_resolved_by_id ON public.disputes USING btree (resolved_by_id);


--
-- Name: index_disputes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disputes_on_status ON public.disputes USING btree (status);


--
-- Name: index_economic_parameters_on_key_and_territory; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_economic_parameters_on_key_and_territory ON public.economic_parameters USING btree (key, territory_id) NULLS NOT DISTINCT;


--
-- Name: index_economic_parameters_on_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_economic_parameters_on_territory_id ON public.economic_parameters USING btree (territory_id);


--
-- Name: index_endorsements_on_endorsed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endorsements_on_endorsed_id ON public.endorsements USING btree (endorsed_id);


--
-- Name: index_endorsements_on_endorser_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_endorsements_on_endorser_id ON public.endorsements USING btree (endorser_id);


--
-- Name: index_endorsements_on_endorser_id_and_endorsed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_endorsements_on_endorser_id_and_endorsed_id ON public.endorsements USING btree (endorser_id, endorsed_id);


--
-- Name: index_feedbacks_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feedbacks_on_kind ON public.feedbacks USING btree (kind);


--
-- Name: index_feedbacks_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feedbacks_on_status ON public.feedbacks USING btree (status);


--
-- Name: index_feedbacks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feedbacks_on_user_id ON public.feedbacks USING btree (user_id);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_type_and_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type_and_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_type, sluggable_id);


--
-- Name: index_identity_verifications_on_reviewed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_verifications_on_reviewed_by_id ON public.identity_verifications USING btree (reviewed_by_id);


--
-- Name: index_identity_verifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_verifications_on_user_id ON public.identity_verifications USING btree (user_id);


--
-- Name: index_identity_verifications_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_verifications_on_user_id_and_status ON public.identity_verifications USING btree (user_id, status);


--
-- Name: index_interactions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interactions_on_post_id ON public.interactions USING btree (post_id);


--
-- Name: index_interactions_on_receiver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interactions_on_receiver_id ON public.interactions USING btree (receiver_id);


--
-- Name: index_interactions_on_sender_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interactions_on_sender_id ON public.interactions USING btree (sender_id);


--
-- Name: index_interactions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interactions_on_status ON public.interactions USING btree (status);


--
-- Name: index_ledger_entries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_account_id ON public.ledger_entries USING btree (account_id);


--
-- Name: index_ledger_entries_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_account_id_and_created_at ON public.ledger_entries USING btree (account_id, created_at);


--
-- Name: index_ledger_entries_on_credit_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_credit_transaction_id ON public.ledger_entries USING btree (credit_transaction_id);


--
-- Name: index_messages_on_hidden_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_hidden_at ON public.messages USING btree (hidden_at);


--
-- Name: index_messages_on_interaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_interaction_id ON public.messages USING btree (interaction_id);


--
-- Name: index_messages_on_interaction_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_interaction_id_and_created_at ON public.messages USING btree (interaction_id, created_at);


--
-- Name: index_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_user_id ON public.messages USING btree (user_id);


--
-- Name: index_notifications_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_actor_id ON public.notifications USING btree (actor_id);


--
-- Name: index_notifications_on_notifiable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_notifiable ON public.notifications USING btree (notifiable_type, notifiable_id);


--
-- Name: index_notifications_on_recipient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_recipient_id ON public.notifications USING btree (recipient_id);


--
-- Name: index_notifications_on_recipient_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_recipient_id_and_created_at ON public.notifications USING btree (recipient_id, created_at);


--
-- Name: index_notifications_on_recipient_id_and_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_recipient_id_and_read_at ON public.notifications USING btree (recipient_id, read_at);


--
-- Name: index_oauth_identities_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_identities_on_provider_and_uid ON public.oauth_identities USING btree (provider, uid);


--
-- Name: index_oauth_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_identities_on_user_id ON public.oauth_identities USING btree (user_id);


--
-- Name: index_page_views_on_visited_on_and_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_page_views_on_visited_on_and_path ON public.page_views USING btree (visited_on, path);


--
-- Name: index_page_views_on_visited_on_and_visitor_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_page_views_on_visited_on_and_visitor_digest ON public.page_views USING btree (visited_on, visitor_digest);


--
-- Name: index_posts_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_category_id ON public.posts USING btree (category_id);


--
-- Name: index_posts_on_hidden_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_hidden_at ON public.posts USING btree (hidden_at);


--
-- Name: index_posts_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_kind ON public.posts USING btree (kind);


--
-- Name: index_posts_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_latitude_and_longitude ON public.posts USING btree (latitude, longitude);


--
-- Name: index_posts_on_pedido; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_pedido ON public.posts USING btree (pedido) WHERE pedido;


--
-- Name: index_posts_on_searchable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_searchable ON public.posts USING gin (searchable);


--
-- Name: index_posts_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_slug ON public.posts USING btree (slug);


--
-- Name: index_posts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_status ON public.posts USING btree (status);


--
-- Name: index_posts_on_title_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_title_trigram ON public.posts USING gin (title public.gin_trgm_ops);


--
-- Name: index_posts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_user_id ON public.posts USING btree (user_id);


--
-- Name: index_proposal_votes_on_proposal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposal_votes_on_proposal_id ON public.proposal_votes USING btree (proposal_id);


--
-- Name: index_proposal_votes_on_proposal_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_proposal_votes_on_proposal_id_and_user_id ON public.proposal_votes USING btree (proposal_id, user_id);


--
-- Name: index_proposal_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposal_votes_on_user_id ON public.proposal_votes USING btree (user_id);


--
-- Name: index_proposals_on_beneficiary_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_beneficiary_id ON public.proposals USING btree (beneficiary_id);


--
-- Name: index_proposals_on_execution_credit_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_execution_credit_transaction_id ON public.proposals USING btree (execution_credit_transaction_id);


--
-- Name: index_proposals_on_proposer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_proposer_id ON public.proposals USING btree (proposer_id);


--
-- Name: index_proposals_on_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_territory_id ON public.proposals USING btree (territory_id);


--
-- Name: index_proposals_on_territory_id_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_territory_id_and_kind ON public.proposals USING btree (territory_id, kind);


--
-- Name: index_proposals_on_territory_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proposals_on_territory_id_and_status ON public.proposals USING btree (territory_id, status);


--
-- Name: index_push_subscriptions_on_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_push_subscriptions_on_endpoint ON public.push_subscriptions USING btree (endpoint);


--
-- Name: index_push_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_push_subscriptions_on_user_id ON public.push_subscriptions USING btree (user_id);


--
-- Name: index_reports_on_reportable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_reportable ON public.reports USING btree (reportable_type, reportable_id);


--
-- Name: index_reports_on_reportable_type_and_reportable_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_reportable_type_and_reportable_id_and_status ON public.reports USING btree (reportable_type, reportable_id, status);


--
-- Name: index_reports_on_reporter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_reporter_id ON public.reports USING btree (reporter_id);


--
-- Name: index_reports_on_resolved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_resolved_by_id ON public.reports USING btree (resolved_by_id);


--
-- Name: index_reports_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_status ON public.reports USING btree (status);


--
-- Name: index_reports_on_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_territory_id ON public.reports USING btree (territory_id);


--
-- Name: index_reviews_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_category_id ON public.reviews USING btree (category_id);


--
-- Name: index_reviews_on_interaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_interaction_id ON public.reviews USING btree (interaction_id);


--
-- Name: index_reviews_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_post_id ON public.reviews USING btree (post_id);


--
-- Name: index_reviews_on_reviewed_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_reviewed_user_id ON public.reviews USING btree (reviewed_user_id);


--
-- Name: index_reviews_on_reviewer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviews_on_reviewer_id ON public.reviews USING btree (reviewer_id);


--
-- Name: index_reviews_on_reviewer_id_and_interaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reviews_on_reviewer_id_and_interaction_id ON public.reviews USING btree (reviewer_id, interaction_id);


--
-- Name: index_saved_searches_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_category_id ON public.saved_searches USING btree (category_id);


--
-- Name: index_saved_searches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_user_id ON public.saved_searches USING btree (user_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_social_broadcasts_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_social_broadcasts_on_post_id ON public.social_broadcasts USING btree (post_id);


--
-- Name: index_social_broadcasts_on_post_id_and_network; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_social_broadcasts_on_post_id_and_network ON public.social_broadcasts USING btree (post_id, network);


--
-- Name: index_territories_on_country_code_and_admin1_and_admin2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_territories_on_country_code_and_admin1_and_admin2 ON public.territories USING btree (country_code, admin1, admin2);


--
-- Name: index_territories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_territories_on_slug ON public.territories USING btree (slug);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_latitude_and_longitude ON public.users USING btree (latitude, longitude);


--
-- Name: index_users_on_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_level ON public.users USING btree (level);


--
-- Name: index_users_on_searchable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_searchable ON public.users USING gin (searchable);


--
-- Name: index_users_on_showcase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_showcase ON public.users USING btree (showcase) WHERE showcase;


--
-- Name: index_users_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_slug ON public.users USING btree (slug);


--
-- Name: index_users_on_sponsor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_sponsor_id ON public.users USING btree (sponsor_id);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: index_users_on_username_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_username_trigram ON public.users USING gin (username public.gin_trgm_ops);


--
-- Name: reviews fk_rails_007031d9cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_007031d9cb FOREIGN KEY (reviewer_id) REFERENCES public.users(id);


--
-- Name: comments fk_rails_03de2dc08c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_03de2dc08c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications fk_rails_06a39bb8cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_06a39bb8cc FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: credit_transactions fk_rails_08d4744162; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT fk_rails_08d4744162 FOREIGN KEY (interaction_id) REFERENCES public.interactions(id);


--
-- Name: credit_transactions fk_rails_0ea2ad3927; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT fk_rails_0ea2ad3927 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: reviews fk_rails_120af22bf9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_120af22bf9 FOREIGN KEY (interaction_id) REFERENCES public.interactions(id);


--
-- Name: interactions fk_rails_266255dee1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT fk_rails_266255dee1 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: reviews fk_rails_266ad806ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_266ad806ea FOREIGN KEY (reviewed_user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_273a25a7a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_273a25a7a6 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: announcement_supports fk_rails_2d9861eb80; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_supports
    ADD CONSTRAINT fk_rails_2d9861eb80 FOREIGN KEY (announcement_id) REFERENCES public.announcements(id);


--
-- Name: oauth_identities fk_rails_2f75762ff1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities
    ADD CONSTRAINT fk_rails_2f75762ff1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: comments fk_rails_2fd19c0db7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: api_keys fk_rails_32c28d0dc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: disputes fk_rails_35800c6514; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT fk_rails_35800c6514 FOREIGN KEY (opener_id) REFERENCES public.users(id);


--
-- Name: social_broadcasts fk_rails_37c4a4f881; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_broadcasts
    ADD CONSTRAINT fk_rails_37c4a4f881 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: identity_verifications fk_rails_3890a13c8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_verifications
    ADD CONSTRAINT fk_rails_3890a13c8b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: proposals fk_rails_396173af2f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT fk_rails_396173af2f FOREIGN KEY (territory_id) REFERENCES public.territories(id);


--
-- Name: endorsements fk_rails_3e1fbae351; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endorsements
    ADD CONSTRAINT fk_rails_3e1fbae351 FOREIGN KEY (endorsed_id) REFERENCES public.users(id);


--
-- Name: direct_messages fk_rails_3f2a70fee4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT fk_rails_3f2a70fee4 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: push_subscriptions fk_rails_43d43720fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT fk_rails_43d43720fc FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications fk_rails_4aea6afa11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_4aea6afa11 FOREIGN KEY (recipient_id) REFERENCES public.users(id);


--
-- Name: direct_messages fk_rails_5b30e38729; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_messages
    ADD CONSTRAINT fk_rails_5b30e38729 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: posts fk_rails_5b5ddfd518; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_5b5ddfd518 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_5d58db3dc7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_5d58db3dc7 FOREIGN KEY (interaction_id) REFERENCES public.interactions(id);


--
-- Name: saved_searches fk_rails_63c5382842; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT fk_rails_63c5382842 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: proposal_votes fk_rails_63cf83a228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposal_votes
    ADD CONSTRAINT fk_rails_63cf83a228 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: interactions fk_rails_7f6cc10769; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT fk_rails_7f6cc10769 FOREIGN KEY (receiver_id) REFERENCES public.users(id);


--
-- Name: disputes fk_rails_826c53563f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT fk_rails_826c53563f FOREIGN KEY (interaction_id) REFERENCES public.interactions(id);


--
-- Name: identity_verifications fk_rails_831b88c251; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_verifications
    ADD CONSTRAINT fk_rails_831b88c251 FOREIGN KEY (reviewed_by_id) REFERENCES public.users(id);


--
-- Name: saved_searches fk_rails_8580e5fb82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT fk_rails_8580e5fb82 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: reports fk_rails_87004f508b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_87004f508b FOREIGN KEY (resolved_by_id) REFERENCES public.users(id);


--
-- Name: accounts fk_rails_892c022088; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_892c022088 FOREIGN KEY (territory_id) REFERENCES public.territories(id);


--
-- Name: announcements fk_rails_9281ffc5d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT fk_rails_9281ffc5d6 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_94f655be82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_94f655be82 FOREIGN KEY (sponsor_id) REFERENCES public.users(id);


--
-- Name: ledger_entries fk_rails_95dd992850; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_95dd992850 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: posts fk_rails_9b1b26f040; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_9b1b26f040 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: credit_transactions fk_rails_9ec011d5a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT fk_rails_9ec011d5a3 FOREIGN KEY (territory_id) REFERENCES public.territories(id);


--
-- Name: proposal_votes fk_rails_a2a3e5ba42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposal_votes
    ADD CONSTRAINT fk_rails_a2a3e5ba42 FOREIGN KEY (proposal_id) REFERENCES public.proposals(id);


--
-- Name: economic_parameters fk_rails_a46ae4bb3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_parameters
    ADD CONSTRAINT fk_rails_a46ae4bb3e FOREIGN KEY (territory_id) REFERENCES public.territories(id);


--
-- Name: reviews fk_rails_a4cffdde38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_a4cffdde38 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: accounts fk_rails_b1e30bebc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_b1e30bebc8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: interactions fk_rails_b3bb9bc7fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT fk_rails_b3bb9bc7fc FOREIGN KEY (sender_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: reports fk_rails_c4cb6e6463; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_c4cb6e6463 FOREIGN KEY (reporter_id) REFERENCES public.users(id);


--
-- Name: conversations fk_rails_c4f2ff267e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_c4f2ff267e FOREIGN KEY (participant_a_id) REFERENCES public.users(id);


--
-- Name: feedbacks fk_rails_c57bb6cf28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks
    ADD CONSTRAINT fk_rails_c57bb6cf28 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: endorsements fk_rails_c853276d9c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endorsements
    ADD CONSTRAINT fk_rails_c853276d9c FOREIGN KEY (endorser_id) REFERENCES public.users(id);


--
-- Name: conversations fk_rails_d5097fba21; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_d5097fba21 FOREIGN KEY (participant_b_id) REFERENCES public.users(id);


--
-- Name: disputes fk_rails_d53be54eee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disputes
    ADD CONSTRAINT fk_rails_d53be54eee FOREIGN KEY (resolved_by_id) REFERENCES public.users(id);


--
-- Name: ledger_entries fk_rails_d5c9da37e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_d5c9da37e3 FOREIGN KEY (credit_transaction_id) REFERENCES public.credit_transactions(id);


--
-- Name: announcement_supports fk_rails_e0056b7a4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_supports
    ADD CONSTRAINT fk_rails_e0056b7a4c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: proposals fk_rails_e392f9e70e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT fk_rails_e392f9e70e FOREIGN KEY (proposer_id) REFERENCES public.users(id);


--
-- Name: reports fk_rails_e48d4f2e71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_e48d4f2e71 FOREIGN KEY (territory_id) REFERENCES public.territories(id);


--
-- Name: proposals fk_rails_f1713137f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT fk_rails_f1713137f4 FOREIGN KEY (beneficiary_id) REFERENCES public.users(id);


--
-- Name: proposals fk_rails_fd17334327; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT fk_rails_fd17334327 FOREIGN KEY (execution_credit_transaction_id) REFERENCES public.credit_transactions(id);


--
-- Name: reviews fk_rails_ff117891ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_rails_ff117891ee FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260927180000'),
('20260927120000'),
('20260826120100'),
('20260826120000'),
('20260710223626'),
('20260710215524'),
('20260705060000'),
('20260705030000'),
('20260705010000'),
('20260704230000'),
('20260704210000'),
('20260704180000'),
('20260703200000'),
('20260702120000'),
('20260613004618'),
('20260610120000'),
('20260610110000'),
('20260610100000'),
('20260609130000'),
('20260609120000'),
('20260528120000'),
('20260527231500'),
('20260527230000'),
('20260521000611'),
('20260520235743'),
('20260517110900'),
('20260517110800'),
('20260517110700'),
('20260517110600'),
('20260517110500'),
('20260517110400'),
('20260517110300'),
('20260517110200'),
('20260517110100'),
('20260517110000'),
('20260517100600'),
('20260517100500'),
('20260517100400'),
('20260517100300'),
('20260517100200'),
('20260517100100'),
('20260517100000'),
('20260516123114'),
('20260516035958'),
('20260516035649'),
('20260516035554'),
('20260516035546'),
('20260516035525'),
('20260516035517'),
('20260516035509'),
('20260516035501'),
('20260516035454'),
('20260516035446'),
('20260516035352'),
('20260516033829'),
('20260516033828');

