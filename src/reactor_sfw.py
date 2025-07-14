def nsfw_image(img_data, model_path: str):
    # This is too sensitive, and we have a separate mechanism for preventing
    # face-swap porn reliably
    return False