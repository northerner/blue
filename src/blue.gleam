import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_args) -> #(Model, Effect(Msg)) {
  let model = Model(fetching: False, posts: [])

  #(model, get_feed("discover"))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedGetFeed(feed_name) -> #(
      Model(..model, fetching: True),
      get_feed(feed_name),
    )

    ApiReturnedFeed(Ok(feed_response)) -> #(
      Model(fetching: False, posts: feed_response.feed),
      effect.none(),
    )

    ApiReturnedFeed(Error(_)) -> #(model, effect.none())
  }
}

type Msg {
  ApiReturnedFeed(Result(FeedResponse, rsvp.Error))
  UserClickedGetFeed(String)
}

type Model {
  Model(fetching: Bool, posts: List(FeedPost))
}

type FeedResponse {
  FeedResponse(feed: List(FeedPost))
}

type FeedPost {
  FeedPost(post: Post)
}

type Post {
  Post(uri: String, author: Author, record: Record, embed: Option(PostEmbed))
}

type PostInPost {
  PostInPost(author: Author, record: Record)
}

type Author {
  Author(handle: String, display_name: String, avatar: String)
}

type Record {
  Record(created_at: String, text: String)
}

type PostEmbed {
  ImagesEmbed(images: List(Image))
  VideoEmbed(playlist: String)
  RecordEmbed(post_in_post: PostInPost)
  ExternalEmbed(
    uri: String,
    title: String,
    description: String,
    thumb: Option(String),
  )
  UnsupportedEmbed(embed_type: String)
}

type Image {
  Image(thumb: String, fullsize: String, alt: String)
}

fn feed_response_decoder() -> decode.Decoder(FeedResponse) {
  use feed <- decode.field("feed", decode.list(feed_post_decoder()))
  decode.success(FeedResponse(feed:))
}

fn feed_post_decoder() -> decode.Decoder(FeedPost) {
  use post <- decode.field("post", post_decoder())
  decode.success(FeedPost(post:))
}

fn post_decoder() -> decode.Decoder(Post) {
  use uri <- decode.field("uri", decode.string)
  use author <- decode.field("author", author_decoder())
  use record <- decode.field("record", record_decoder())

  use embed <- decode.optional_field(
    "embed",
    None,
    decode.optional(embed_decoder()),
  )

  decode.success(Post(uri:, author:, record:, embed:))
}

fn post_in_post_decoder() -> decode.Decoder(PostInPost) {
  use author <- decode.field("author", author_decoder())
  use record <- decode.field("value", record_decoder())

  decode.success(PostInPost(author:, record:))
}

fn author_decoder() -> decode.Decoder(Author) {
  use handle <- decode.field("handle", decode.string)
  use display_name <- decode.field("displayName", decode.string)
  use avatar <- decode.field("avatar", decode.string)
  decode.success(Author(handle:, display_name:, avatar:))
}

fn record_decoder() -> decode.Decoder(Record) {
  use created_at <- decode.field("createdAt", decode.string)
  use text <- decode.field("text", decode.string)
  decode.success(Record(created_at:, text:))
}

fn embed_decoder() -> decode.Decoder(PostEmbed) {
  use embed_type <- decode.field("$type", decode.string)
  echo embed_type

  case embed_type {
    "app.bsky.embed.images#view" -> {
      use images <- decode.field("images", decode.list(image_decoder()))
      decode.success(ImagesEmbed(images))
    }
    "app.bsky.embed.video#view" -> {
      use playlist <- decode.field("playlist", decode.string)
      decode.success(VideoEmbed(playlist))
    }
    // "app.bsky.embed.record#view" -> {
    //   use post_in_post <- decode.field("record", post_in_post_decoder())
    //   decode.success(RecordEmbed(post_in_post))
    // }
    "app.bsky.embed.external#view" -> {
      use uri <- decode.subfield(["external", "uri"], decode.string)
      use title <- decode.subfield(["external", "title"], decode.string)
      use description <- decode.subfield(
        ["external", "description"],
        decode.string,
      )
      use thumb <- decode.then(decode.optionally_at(
        ["external", "thumb"],
        None,
        decode.optional(decode.string),
      ))
      decode.success(ExternalEmbed(uri:, title:, description:, thumb:))
    }
    t -> decode.success(UnsupportedEmbed(t))
  }
}

fn image_decoder() -> decode.Decoder(Image) {
  use thumb <- decode.field("thumb", decode.string)
  use fullsize <- decode.field("fullsize", decode.string)
  use alt <- decode.field("alt", decode.string)
  decode.success(Image(thumb:, fullsize:, alt:))
}

fn get_feed(name) {
  let path = case name {
    "birds" ->
      "at://did:plc:ffkgesg3jsv2j7aagkzrtcvt/app.bsky.feed.generator/aaagllxbcbsje"
    "beam" ->
      "at://did:plc:2hgt4vfh2jxuwf5zllcbed64/app.bsky.feed.generator/aaaemobjvwlsq"
    "books" ->
      "at://did:plc:geoqe3qls5mwezckxxsewys2/app.bsky.feed.generator/aaabrbjcg4hmk"
    _discover ->
      "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
  }

  let url = "https://api.bsky.app/xrpc/app.bsky.feed.getFeed?feed=" <> path
  let handler = rsvp.expect_json(feed_response_decoder(), ApiReturnedFeed)

  rsvp.get(url, handler)
}

fn view(model: Model) -> Element(Msg) {
  html.html([], [
    html.head([], [
      html.link([
        attribute.rel("stylesheet"),
        attribute.href(
          "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.jade.min.css",
        ),
      ]),
    ]),
    html.body([], [
      html.main([attribute.class("container")], [
        html.nav([], [
          html.ul([], [html.li([], [html.strong([], [html.text("Blue")])])]),
          html.ul([], [
            html.li([], [
              html.button(
                [
                  event.on_click(UserClickedGetFeed("discover")),
                  attribute.disabled(model.fetching),
                ],
                [html.text("Discover")],
              ),
            ]),
            html.li([], [
              html.button(
                [
                  event.on_click(UserClickedGetFeed("birds")),
                  attribute.disabled(model.fetching),
                ],
                [html.text("Birds")],
              ),
            ]),
            html.li([], [
              html.button(
                [
                  event.on_click(UserClickedGetFeed("beam")),
                  attribute.disabled(model.fetching),
                ],
                [html.text("BEAM")],
              ),
            ]),
            html.li([], [
              html.button(
                [
                  event.on_click(UserClickedGetFeed("books")),
                  attribute.disabled(model.fetching),
                ],
                [html.text("Books")],
              ),
            ]),
          ]),
        ]),
        html.div([], {
          list.map(model.posts, fn(post) {
            html.article([], [
              html.header([], [
                html.span([], [
                  html.img([
                    attribute.src(post.post.author.avatar),
                    attribute.width(50),
                  ]),
                ]),
                html.strong([], [
                  html.text(" "),
                  html.text(post.post.author.handle),
                ]),
              ]),
              html.text(post.post.record.text),
              html.div([attribute.class("grid")], {
                case post.post.embed {
                  Some(ImagesEmbed(images)) ->
                    list.map(images, fn(image) {
                      html.img([
                        attribute.src(image.thumb),
                        attribute.style("max-height", "50vh"),
                        attribute.alt(image.alt),
                        attribute.title(image.alt),
                      ])
                    })
                  Some(VideoEmbed(playlist)) -> [
                    html.video(
                      [
                        attribute.controls(True),
                        attribute.style("max-width", "100%"),
                        attribute.style("max-height", "50vh"),
                      ],
                      [html.source([attribute.src(playlist)])],
                    ),
                  ]
                  Some(RecordEmbed(post_in_post:)) -> [
                    html.article([], [
                      html.header([], [
                        html.span([], [
                          html.img([
                            attribute.src(post_in_post.author.avatar),
                            attribute.width(50),
                          ]),
                        ]),
                        html.strong([], [
                          html.text(" "),
                          html.text(post_in_post.author.handle),
                        ]),
                      ]),
                      html.text(post.post.record.text),
                      html.footer([], [
                        html.small([], [
                          html.text(post_in_post.record.created_at),
                        ]),
                      ]),
                    ]),
                  ]
                  Some(ExternalEmbed(uri:, title:, description:, thumb:)) -> [
                    html.article([], [
                      case thumb {
                        Some(thumb_src) ->
                          html.img([
                            attribute.src(thumb_src),
                            attribute.style("max-height", "50vh"),
                          ])
                        None -> html.text("")
                      },
                      html.footer([], [
                        html.a([attribute.href(uri)], [
                          case title {
                            "" -> html.strong([], [html.text(uri)])
                            text -> html.strong([], [html.text(text)])
                          },
                        ]),
                        html.p([], [html.text(description)]),
                      ]),
                    ]),
                  ]
                  Some(UnsupportedEmbed(embed_type)) -> [
                    html.small([], [
                      html.text("Unsupported embed type: " <> embed_type),
                    ]),
                  ]
                  None -> []
                }
              }),
              html.footer([], [
                html.small([], [html.text(post.post.record.created_at)]),
              ]),
            ])
          })
        }),
      ]),
    ]),
  ])
}
