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

  #(model, get_feed())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedGetFeed -> #(Model(..model, fetching: True), get_feed())

    ApiReturnedFeed(Ok(feed_response)) -> #(
      Model(
        fetching: False,
        posts: list.append(feed_response.feed, model.posts),
      ),
      effect.none(),
    )

    ApiReturnedFeed(Error(_)) -> #(model, effect.none())
  }
}

type Msg {
  ApiReturnedFeed(Result(FeedResponse, rsvp.Error))
  UserClickedGetFeed
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

type Author {
  Author(handle: String, display_name: String, avatar: String)
}

type Record {
  Record(created_at: String, text: String)
}

type PostEmbed {
  ImagesEmbed(images: List(Image))
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

  echo embed

  decode.success(Post(uri:, author:, record:, embed:))
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
    t -> decode.success(UnsupportedEmbed(t))
  }
}

fn image_decoder() -> decode.Decoder(Image) {
  use thumb <- decode.field("thumb", decode.string)
  use fullsize <- decode.field("fullsize", decode.string)
  use alt <- decode.field("alt", decode.string)
  decode.success(Image(thumb:, fullsize:, alt:))
}

fn get_feed() {
  let url =
    "https://api.bsky.app/xrpc/app.bsky.feed.getFeed?feed=at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
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
                  event.on_click(UserClickedGetFeed),
                  attribute.disabled(model.fetching),
                ],
                [html.text("Refresh")],
              ),
            ]),
          ]),
        ]),
        html.div([], {
          list.map(model.posts, fn(post) {
            html.article([], [
              html.header([attribute.class("")], [
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
                  Some(UnsupportedEmbed(_type)) -> {
                    []
                  }
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
